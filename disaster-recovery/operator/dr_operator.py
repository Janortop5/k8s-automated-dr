#!/usr/bin/env python3
"""
Simple Kubernetes Disaster Recovery Operator using Kopf
Based on the FYP project: ML-enhanced automated recovery framework
"""

import kopf
import kubernetes
import asyncio
import logging
from datetime import datetime
from typing import Dict, Any

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Kubernetes client
kubernetes.config.load_incluster_config()  # Use this when running in cluster
# kubernetes.config.load_kube_config()  # Use this for local development
k8s_apps_v1 = kubernetes.client.AppsV1Api()
k8s_core_v1 = kubernetes.client.CoreV1Api()


@kopf.on.startup()
def configure(settings: kopf.OperatorSettings, **_):
    """Configure the operator settings"""
    settings.posting.level = logging.INFO
    logger.info("Disaster Recovery Operator starting up...")


@kopf.on.create('disasters.k8s-failsafe.io', 'v1', 'recoveryconfigs')
async def create_recovery_config(body, name, namespace, **kwargs):
    """
    Handle creation of RecoveryConfig custom resource
    This represents the declarative DR plan mentioned in your project
    """
    logger.info(f"Creating RecoveryConfig: {name} in namespace: {namespace}")
    
    # Extract configuration from the custom resource
    spec = body.get('spec', {})
    anomaly_threshold = spec.get('anomalyThreshold', 0.9)
    recovery_actions = spec.get('recoveryActions', ['restart'])
    
    # Update status to indicate the config is active
    return {
        'status': {
            'phase': 'Active',
            'anomalyThreshold': anomaly_threshold,
            'recoveryActions': recovery_actions,
            'lastUpdated': datetime.utcnow().isoformat()
        }
    }


@kopf.on.field('disasters.k8s-failsafe.io', 'v1', 'recoveryconfigs', field='spec.anomalyScore')
async def handle_anomaly_detection(old, new, body, name, namespace, **kwargs):
    """
    React to anomaly score changes - core ML integration point
    This simulates receiving ML model predictions from your LSTM pipeline
    """
    if new is None:
        return
    
    anomaly_score = float(new)
    threshold = body.get('spec', {}).get('anomalyThreshold', 0.9)
    
    logger.info(f"Anomaly score updated: {anomaly_score} (threshold: {threshold})")
    
    if anomaly_score > threshold:
        logger.warning(f"Anomaly detected! Score: {anomaly_score}")
        await trigger_recovery_action(body, name, namespace, anomaly_score)
    
    # Update status with latest anomaly score
    return {
        'status': {
            'lastAnomalyScore': anomaly_score,
            'lastAnomalyTime': datetime.utcnow().isoformat(),
            'anomalyDetected': anomaly_score > threshold
        }
    }


async def trigger_recovery_action(body: Dict[str, Any], name: str, namespace: str, score: float):
    """
    Implement graduated recovery actions based on your project's approach:
    1. Pod restart
    2. Deployment rollback  
    3. Node drain
    4. Full Velero restore
    """
    spec = body.get('spec', {})
    recovery_actions = spec.get('recoveryActions', ['restart'])
    target_deployment = spec.get('targetDeployment')
    
    if not target_deployment:
        logger.error("No target deployment specified for recovery")
        return
    
    # Determine recovery action based on anomaly score severity
    if score > 0.95:
        action = 'velero-restore'
    elif score > 0.92:
        action = 'node-drain'
    elif score > 0.90:
        action = 'rollback'
    else:
        action = 'restart'
    
    logger.info(f"Executing recovery action: {action} for deployment: {target_deployment}")
    
    try:
        if action == 'restart':
            await restart_deployment(target_deployment, namespace)
        elif action == 'rollback':
            await rollback_deployment(target_deployment, namespace)
        elif action == 'node-drain':
            logger.info("Node drain would be executed (not implemented in this example)")
        elif action == 'velero-restore':
            logger.info("Velero restore would be triggered (not implemented in this example)")
            
    except Exception as e:
        logger.error(f"Recovery action failed: {e}")
        raise kopf.PermanentError(f"Recovery failed: {e}")


async def restart_deployment(deployment_name: str, namespace: str):
    """Restart deployment by updating annotation to trigger rollout"""
    try:
        # Get current deployment
        deployment = k8s_apps_v1.read_namespaced_deployment(
            name=deployment_name, 
            namespace=namespace
        )
        
        # Add restart annotation to trigger rollout
        if not deployment.spec.template.metadata.annotations:
            deployment.spec.template.metadata.annotations = {}
            
        deployment.spec.template.metadata.annotations['kubectl.kubernetes.io/restartedAt'] = \
            datetime.utcnow().isoformat()
        
        # Update deployment
        k8s_apps_v1.patch_namespaced_deployment(
            name=deployment_name,
            namespace=namespace,
            body=deployment
        )
        
        logger.info(f"Successfully restarted deployment: {deployment_name}")
        
    except kubernetes.client.rest.ApiException as e:
        logger.error(f"Failed to restart deployment {deployment_name}: {e}")
        raise


async def rollback_deployment(deployment_name: str, namespace: str):
    """Rollback deployment to previous revision"""
    try:
        # Get deployment
        deployment = k8s_apps_v1.read_namespaced_deployment(
            name=deployment_name,
            namespace=namespace
        )
        
        # Trigger rollback by updating revision annotation
        if not deployment.metadata.annotations:
            deployment.metadata.annotations = {}
            
        deployment.metadata.annotations['deployment.kubernetes.io/revision'] = 'rollback'
        
        k8s_apps_v1.patch_namespaced_deployment(
            name=deployment_name,
            namespace=namespace,
            body=deployment
        )
        
        logger.info(f"Successfully initiated rollback for deployment: {deployment_name}")
        
    except kubernetes.client.rest.ApiException as e:
        logger.error(f"Failed to rollback deployment {deployment_name}: {e}")
        raise


@kopf.on.timer('disasters.k8s-failsafe.io', 'v1', 'recoveryconfigs', interval=30.0)
async def monitor_health(body, name, namespace, **kwargs):
    """
    Periodic health monitoring - where you'd integrate with Prometheus
    This simulates the continuous monitoring aspect of your project
    """
    spec = body.get('spec', {})
    target_deployment = spec.get('targetDeployment')
    
    if not target_deployment:
        return
    
    try:
        # Check deployment health
        deployment = k8s_apps_v1.read_namespaced_deployment(
            name=target_deployment,
            namespace=namespace
        )
        
        ready_replicas = deployment.status.ready_replicas or 0
        desired_replicas = deployment.spec.replicas or 0
        
        health_score = ready_replicas / desired_replicas if desired_replicas > 0 else 0
        
        logger.debug(f"Health check for {target_deployment}: {ready_replicas}/{desired_replicas} ready")
        
        # In real implementation, this would query your LSTM model
        # For demo, we simulate anomaly score based on health
        simulated_anomaly_score = 1.0 - health_score
        
        # Update the RecoveryConfig with simulated anomaly score
        return {
            'spec': {
                **spec,
                'anomalyScore': simulated_anomaly_score
            },
            'status': {
                'lastHealthCheck': datetime.utcnow().isoformat(),
                'deploymentHealth': health_score,
                'readyReplicas': ready_replicas,
                'desiredReplicas': desired_replicas
            }
        }
        
    except kubernetes.client.rest.ApiException as e:
        logger.error(f"Health check failed for {target_deployment}: {e}")
        return {'status': {'lastError': str(e)}}


@kopf.on.delete('disasters.k8s-failsafe.io', 'v1', 'recoveryconfigs')
async def delete_recovery_config(body, name, namespace, **kwargs):
    """Clean up when RecoveryConfig is deleted"""
    logger.info(f"Cleaning up RecoveryConfig: {name} in namespace: {namespace}")
    

if __name__ == '__main__':
    # Run the operator
    kopf.run()
