import time
import requests
from loguru import logger
import os
from datetime import datetime, timezone
from typing import List, Dict, Optional
import signal
import sys
from collections import deque
import statistics
from alert_manager import AlertManager


class PrometheusMetricsCollector:
    def __init__(self):
        self.prometheus_url = os.getenv(
            'PROMETHEUS_URL',
            'http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090')
        self.model_endpoint = os.getenv(
            'MODEL_ENDPOINT',
            'http://lstm-model-service.monitoring.svc.cluster.local/predict')
        self.collection_interval = int(
            os.getenv(
                'COLLECTION_INTERVAL',
                '30'))  # seconds
        self.sequence_length = int(
            os.getenv(
                'SEQUENCE_LENGTH',
                '1'))  # number of data points for LSTM
        self.alert_manager = AlertManager()  # Initialize the alert manager
        self.auth_token = os.getenv(
            'PROMETHEUS_AUTH_TOKEN')  # Optional Bearer token
        # Optional basic auth user
        self.auth_user = os.getenv('PROMETHEUS_AUTH_USER')
        # Optional basic auth password
        self.auth_pass = os.getenv('PROMETHEUS_AUTH_PASS')

        # Buffer to store time series data
        self.metrics_buffer = deque(maxlen=self.sequence_length)
        self.running = True

        # Prometheus queries
        self.metrics_queries = {
            # Disk I/O (read + write bytes per second)
            'disk_io': '''
            rate(container_fs_reads_bytes_total[5m]) + rate(container_fs_writes_bytes_total[5m])
            ''',

            # Node temperature (if available via node exporter)
            'node_temperature': '''
            node_hwmon_temp_celsius
            ''',

            # Node CPU usage percentage
            'node_cpu_usage': '''
            100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
            ''',

            # Node memory usage percentage
            'node_memory_usage': '''
            (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
            ''',

            # Pod lifetime in seconds
            'pod_lifetime_seconds': '''
            time() - kube_pod_created
            '''
        }

        logger.info(f"Initialized PrometheusMetricsCollector:")
        logger.info(f"  Prometheus URL: {self.prometheus_url}")
        logger.info(f"  Model endpoint: {self.model_endpoint}")
        logger.info(f"  Collection interval: {self.collection_interval}s")
        logger.info(f"  Sequence length: {self.sequence_length}")

    def _get_auth_headers(self) -> Dict[str, str]:
        """Get authentication headers for Prometheus requests"""
        headers = {'Content-Type': 'application/json'}

        if self.auth_token:
            headers['Authorization'] = f'Bearer {self.auth_token}'
            logger.debug("Using Bearer token authentication")

        return headers

    def _get_auth_config(self) -> Optional[tuple]:
        """Get authentication config for requests"""
        if self.auth_user and self.auth_pass:
            logger.debug("Using basic authentication")
            return (self.auth_user, self.auth_pass)
        return None

    def query_prometheus_single(self, query: str) -> Optional[List[Dict]]:
        """Query Prometheus for current values (instant query)"""
        try:
            url = f"{self.prometheus_url}/api/v1/query"
            params = {'query': query.strip()}
            headers = self._get_auth_headers()
            auth = self._get_auth_config()

            response = requests.get(
                url,
                params=params,
                headers=headers,
                auth=auth,
                timeout=30)
            response.raise_for_status()

            data = response.json()
            if data['status'] != 'success':
                logger.error(f"Prometheus query failed: {data}")
                return None

            return data['data']['result']

        except requests.exceptions.RequestException as e:
            logger.error(f"Error querying Prometheus: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error in Prometheus query: {e}")
            return None

    def query_prometheus_range(self,
                               query: str,
                               duration: str = '5m',
                               step: str = '30s') -> Optional[List[Dict]]:
        """Query Prometheus for time series data (range query)"""
        try:
            url = f"{self.prometheus_url}/api/v1/query_range"
            end_time = datetime.now(timezone.utc)
            start_time = end_time.timestamp() - self._parse_duration(duration)

            params = {
                'query': query.strip(),
                'start': start_time,
                'end': end_time.timestamp(),
                'step': step
            }

            headers = self._get_auth_headers()
            auth = self._get_auth_config()

            response = requests.get(
                url,
                params=params,
                headers=headers,
                auth=auth,
                timeout=30)
            response.raise_for_status()

            data = response.json()
            if data['status'] != 'success':
                logger.error(f"Prometheus range query failed: {data}")
                return None

            return data['data']['result']

        except Exception as e:
            logger.error(f"Error in Prometheus range query: {e}")
            return None

    def _parse_duration(self, duration: str) -> int:
        """Parse duration string to seconds (e.g., '5m' -> 300)"""
        duration = duration.strip().lower()
        if duration.endswith('s'):
            return int(duration[:-1])
        elif duration.endswith('m'):
            return int(duration[:-1]) * 60
        elif duration.endswith('h'):
            return int(duration[:-1]) * 3600
        else:
            return int(duration)

    def aggregate_metric_values(
            self,
            results: List[Dict],
            aggregation: str = 'mean') -> float:
        """Aggregate metric values across multiple series"""
        if not results:
            return 0.0

        values = []
        for result in results:
            if 'value' in result and len(result['value']) == 2:
                # Single value query result
                try:
                    values.append(float(result['value'][1]))
                except (ValueError, IndexError):
                    continue
            elif 'values' in result:
                # Range query result - use latest value
                try:
                    values.append(float(result['values'][-1][1]))
                except (ValueError, IndexError):
                    continue

        if not values:
            return 0.0

        if aggregation == 'mean':
            return statistics.mean(values)
        elif aggregation == 'max':
            return max(values)
        elif aggregation == 'min':
            return min(values)
        elif aggregation == 'sum':
            return sum(values)
        else:
            return statistics.mean(values)

    def collect_current_metrics(self) -> Optional[Dict[str, float]]:
        """Collect current metric values from Prometheus"""
        try:
            metrics = {}

            for metric_name, query in self.metrics_queries.items():
                logger.info(f"Querying {metric_name}: {query}")
                results = self.query_prometheus_single(query)

                if results:
                    # Aggregate values across all instances/nodes
                    aggregated_value = self.aggregate_metric_values(
                        results, 'mean')
                    metrics[metric_name] = aggregated_value
                    logger.info(f"{metric_name}: {aggregated_value}")
                else:
                    logger.warning(f"No data returned for {metric_name}")
                    metrics[metric_name] = 0.0

            logger.info(f"Collected metrics: {metrics}")
            return metrics

        except Exception as e:
            logger.error(f"Error collecting metrics: {e}")
            return None

    def collect_time_series_metrics(
            self, duration: str = '10m') -> Optional[List[Dict[str, float]]]:
        """Collect time series data for multiple timestamps"""
        try:
            time_series_data = []

            # Get time series for each metric
            all_series = {}
            for metric_name, query in self.metrics_queries.items():
                logger.info(f"Querying time series for {metric_name}")
                results = self.query_prometheus_range(query, duration)

                if results:
                    # Extract time series values
                    series_values = []
                    for result in results:
                        if 'values' in result:
                            for timestamp, value in result['values']:
                                try:
                                    series_values.append(
                                        (float(timestamp), float(value)))
                                except ValueError:
                                    continue

                    if series_values:
                        # Sort by timestamp and aggregate if multiple series
                        series_values.sort(key=lambda x: x[0])
                        all_series[metric_name] = series_values
                else:
                    logger.warning(f"No time series data for {metric_name}")
                    all_series[metric_name] = []

            # Align timestamps and create sequence
            if all_series:
                # Find common timestamps (simplified approach)
                timestamps = set()
                for series in all_series.values():
                    if series:
                        timestamps.update([ts for ts, _ in series])

                # Sort timestamps and take recent ones
                sorted_timestamps = sorted(timestamps)[-self.sequence_length:]

                for ts in sorted_timestamps:
                    metrics_point = {}
                    for metric_name in self.metrics_queries.keys():
                        # Find closest value for this timestamp
                        series = all_series.get(metric_name, [])
                        if series:
                            closest_value = min(
                                series, key=lambda x: abs(
                                    x[0] - ts))[1]
                            metrics_point[metric_name] = closest_value
                        else:
                            metrics_point[metric_name] = 0.0

                    time_series_data.append(metrics_point)

            logger.info(
                f"Collected {
                    len(time_series_data)} time series points")
            return time_series_data

        except Exception as e:
            logger.error(f"Error collecting time series metrics: {e}")
            return None

    def normalize_metrics(self, metrics: Dict[str, float]) -> List[float]:
        """Normalize metrics for model input"""
        try:
            # Define normalization ranges (adjust based on your model training)
            normalization_ranges = {
                'disk_io': {'min': 0, 'max': 1000000},  # 0-1MB/s
                'node_temperature': {'min': 20, 'max': 80},  # 20-80°C
                # 'node_cpu_usage': {'min': 0, 'max': 100},  # 0-100%
                # 'node_memory_usage': {'min': 0, 'max': 100},  # 0-100%
                'pod_lifetime_seconds': {'min': 0, 'max': 86400}  # 0-24 hours
            }

            normalized = []
            for metric_name in [
                'disk_io',
                'node_temperature',
                    'pod_lifetime_seconds']:  # 'node_cpu_usage',  'node_memory_usage',
                value = metrics.get(metric_name, 0.0)
                min_val = normalization_ranges[metric_name]['min']
                max_val = normalization_ranges[metric_name]['max']

                # Min-max normalization to [0, 1]
                normalized_value = (value - min_val) / (max_val - min_val)
                normalized_value = max(
                    0, min(1, normalized_value))  # Clamp to [0, 1]
                normalized.append(normalized_value)

            return normalized

        except Exception as e:
            logger.error(f"Error normalizing metrics: {e}")
            return None

    def send_prediction_request(
            self, sequence_data: List[List[float]]) -> Optional[Dict]:
        """Send sequence data to LSTM model for prediction"""
        try:
            payload = {"data": sequence_data}

            response = requests.post(
                self.model_endpoint,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30
            )

            if response.status_code == 200:
                result = response.json()
                logger.info(f"Prediction successful: {result}")

                # Check predictions against thresholds
                if result and 'predictions' in result:
                    alerts = self.alert_manager.check_prediction(
                        result['predictions'])
                    if alerts:
                        logger.warning(f"Generated alerts: {alerts}")

                return result
            else:
                logger.error(f"Prediction failed: {
                             response.status_code} - {response.text}")
                return None

        except Exception as e:
            logger.error(f"Error sending prediction request: {e}")
            return None

    def run_single_collection(self):
        """Run a single collection cycle with current metrics"""
        metrics = self.collect_current_metrics()
        if metrics:
            normalized = self.normalize_metrics(metrics)
            if normalized:
                self.metrics_buffer.append(normalized)

                if len(self.metrics_buffer) >= self.sequence_length:
                    # Send sequence to model
                    sequence = list(self.metrics_buffer)
                    self.send_prediction_request(sequence)

    def run_time_series_collection(self):
        """Run collection with time series data"""
        time_series = self.collect_time_series_metrics()
        if time_series and len(time_series) >= self.sequence_length:
            # Normalize each time point
            normalized_sequence = []
            for metrics_point in time_series[-self.sequence_length:]:
                normalized = self.normalize_metrics(metrics_point)
                if normalized:
                    normalized_sequence.append(normalized)

            if len(normalized_sequence) == self.sequence_length:
                self.send_prediction_request(normalized_sequence)

    def run_collector(self, use_time_series: bool = False):
        """Main collection loop"""
        logger.info("Starting metrics collection...")

        while self.running:
            # try:
            if use_time_series:
                self.run_time_series_collection()
            else:
                self.run_single_collection()

            time.sleep(self.collection_interval)

            # except KeyboardInterrupt:
            #     logger.info("Received interrupt signal, stopping...")
            #     self.running = False
            # except Exception as e:
            #     logger.error(f"Error in collection loop: {e}")
            #     time.sleep(self.collection_interval)

    def stop(self):
        """Stop the collector"""
        self.running = False


def signal_handler(signum, frame):
    """Handle shutdown signals"""
    logger.info(f"Received signal {signum}, shutting down...")
    collector.stop()
    sys.exit(0)


if __name__ == "__main__":
    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Create and start collector
    collector = PrometheusMetricsCollector()

    # Choose collection mode
    use_time_series = os.getenv('USE_TIME_SERIES', 'false').lower() == 'true'

    try:
        collector.run_collector(use_time_series=use_time_series)
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)
