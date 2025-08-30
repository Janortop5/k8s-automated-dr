import logging
import os
from typing import List, Dict
import requests
from datetime import datetime
import requests
import json

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class AlertManager:
    def __init__(self):
        # Alert thresholds (can be configured via env vars)
        self.cpu_threshold = float(
            os.getenv(
                'ALERT_CPU_THRESHOLD',
                '30.0'))  # CPU usage %
        self.memory_threshold = float(
            os.getenv(
                'ALERT_MEMORY_THRESHOLD',
                '30.0'))  # Memory usage %

        # Alert configuration
        self.slack_webhook = os.getenv('SLACK_WEBHOOK_URL')
        self.teams_webhook = os.getenv('TEAMS_WEBHOOK_URL')
        self.alert_cooldown = int(
            os.getenv(
                'ALERT_COOLDOWN_SECONDS',
                '300'))  # 5 minutes
        self.api_gateway_url = os.getenv('API_GATEWAY_URL')
        # Track last alert times to prevent alert flooding
        self.last_alert_times: Dict[str, datetime] = {}

    def _is_cooldown_active(self, metric_name: str) -> bool:
        """Check if the cooldown period is still active for a specific metric"""
        if metric_name not in self.last_alert_times:
            return False

        time_since_last_alert = datetime.now(
        ) - self.last_alert_times[metric_name]
        return time_since_last_alert.total_seconds() < self.alert_cooldown

    def trigger_deployment(self):
        """Trigger deployment via external API"""
        logger.info("Triggering deployment...")
        headers = {
            "Content-Type": "application/json"
        }
        data = {
            "parameters": {
                "deploy_standby_only": "false",
                "destroy_after_apply": "false",
                "skip_tests": "false"
            }
        }

        try:
            response = requests.post(self.api_gateway_url, headers=headers, json=data, timeout=10)
            if response.status_code == 200:
                logger.info("Triggered deployment successfully")
            else:
                logger.error(f"Deployment trigger failed: {response.status_code} {response.text}")
        except Exception as e:
            logger.exception("Exception occurred while triggering deployment")

    def _update_last_alert_time(self, metric_name: str):
        """Update the last alert time for a specific metric"""
        self.last_alert_times[metric_name] = datetime.now()

    def check_prediction(self, predictions: dict) -> List[Dict]:
        """
        Check predictions against thresholds and generate alerts if needed
        Returns list of alerts that were generated
        """
        alerts = []
        current_time = datetime.now()

        memory_predictions = predictions['mem_usage']
        cpu_predictions = predictions['cpu_usage']

        mem_exceeds = [
            val for val in memory_predictions if val > self.memory_threshold]
        cpu_exceeds = [
            val for val in cpu_predictions if val > self.cpu_threshold]

        # Check memory usage with cooldown
        if mem_exceeds and not self._is_cooldown_active('memory'):
            alert = {
                'metric': "Memory Usage",
                'prediction': max(memory_predictions),
                'threshold': self.memory_threshold,
                "unit": "Percentage (%)",
                'timestamp': current_time.isoformat()
            }
            alerts.append(alert)
            self._update_last_alert_time('memory')
            logger.info("Memory alert triggered - cooldown timer reset")
        elif mem_exceeds and self._is_cooldown_active('memory'):
            # Calculate remaining cooldown time
            time_since_last = datetime.now() - self.last_alert_times['memory']
            remaining_seconds = self.alert_cooldown - time_since_last.total_seconds()
            logger.info(f"Memory threshold exceeded but alert suppressed due to cooldown. "
                        f"Remaining cooldown: {remaining_seconds:.0f} seconds")

        # Check CPU usage with cooldown
        if cpu_exceeds and not self._is_cooldown_active('cpu'):
            alert = {
                'metric': "CPU Usage",
                'prediction': max(cpu_predictions),
                'threshold': self.cpu_threshold,
                "unit": "Percentage (%)",
                'timestamp': current_time.isoformat()
            }
            alerts.append(alert)
            self._update_last_alert_time('cpu')
            logger.info("CPU alert triggered - cooldown timer reset")
        elif cpu_exceeds and self._is_cooldown_active('cpu'):
            # Calculate remaining cooldown time
            time_since_last = datetime.now() - self.last_alert_times['cpu']
            remaining_seconds = self.alert_cooldown - time_since_last.total_seconds()
            logger.info(f"CPU threshold exceeded but alert suppressed due to cooldown. "
                        f"Remaining cooldown: {remaining_seconds:.0f} seconds")

        if alerts:
            logger.warning(f"Sending alerts: {alerts}")
            self._send_alert(alerts)
            if self.api_gateway_url:
                self.trigger_deployment()

        return alerts

    def _send_alert(self, alerts: List[Dict]) -> bool:
        """Send combined alert to configured notification channels"""
        success = False

        header = "🚨 *Resource Usage Alert(s)*\n"
        body = ""

        for alert in alerts:
            body += (
                f"\n*{alert['metric']}*:\n"
                f"• Prediction: {alert['prediction']:.2f}{alert['unit']}\n"
                f"• Threshold: {alert['threshold']}{alert['unit']}\n"
                f"• Time: {alert['timestamp']}\n"
            )

        message = header + body.strip()

        # Try Slack
        if self.slack_webhook:
            try:
                response = requests.post(
                    self.slack_webhook,
                    json={'text': message},
                    timeout=5
                )
                if response.status_code == 200:
                    logger.info("Alert sent to Slack successfully")
                    success = True
                else:
                    logger.error(f"Failed to send Slack alert: {response.status_code}")
            except Exception as e:
                logger.error(f"Error sending Slack alert: {e}")

        # Try Microsoft Teams
        if self.teams_webhook:
            try:
                teams_message = {
                    '@type': 'MessageCard',
                    '@context': 'http://schema.org/extensions',
                    'summary': 'Resource Usage Alert',
                    'themeColor': 'FF0000',
                    'title': 'Resource Usage Alert',
                    'text': message
                }

                response = requests.post(
                    self.teams_webhook,
                    json=teams_message,
                    timeout=5
                )
                if response.status_code == 200:
                    logger.info("Alert sent to Teams successfully")
                    success = True
                else:
                    logger.error(f"Failed to send Teams alert: {response.status_code}")
            except Exception as e:
                logger.error(f"Error sending Teams alert: {e}")

        return success

    def get_cooldown_status(self) -> Dict[str, Dict]:
        """Get current cooldown status for all metrics - useful for debugging"""
        status = {}
        current_time = datetime.now()

        for metric, last_alert_time in self.last_alert_times.items():
            time_since_last = current_time - last_alert_time
            remaining_seconds = max(
                0, self.alert_cooldown - time_since_last.total_seconds())

            status[metric] = {
                'last_alert_time': last_alert_time.isoformat(),
                'time_since_last_alert_seconds': time_since_last.total_seconds(),
                'cooldown_active': remaining_seconds > 0,
                'remaining_cooldown_seconds': remaining_seconds}

        return status
