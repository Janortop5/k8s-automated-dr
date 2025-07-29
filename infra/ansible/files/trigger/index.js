const express = require('express');
const redis = require('redis');
const axios = require('axios');
const https = require('https');

class StreamlinedNodeJSTrigger {
    constructor() {
        this.app = express();
        this.redisClient = null;
        this.vaultClient = null;
        this.config = this.loadConfig();
        
        this.app.use(express.json());
        this.app.use(express.urlencoded({ extended: true }));
        
        this.init();
    }

    loadConfig() {
        return {
            redis: {
                host: process.env.REDIS_HOST || 'localhost',
                port: process.env.REDIS_PORT || 6379
            },
            vault: {
                addr: process.env.VAULT_ADDR || 'http://localhost:8200',
                token: process.env.VAULT_TOKEN || ''
            },
            jenkins: {
                url: process.env.JENKINS_URL || 'http://localhost:8080',
                pipeline_name: process.env.PIPELINE_NAME || 'DR-Pipeline'
            },
            server: {
                port: process.env.PORT || 3000,
                host: process.env.HOST || '0.0.0.0'
            }
        };
    }

    async init() {
        try {
            // Initialize Redis connection
            this.redisClient = redis.createClient({
                socket: {
                    host: this.config.redis.host,
                    port: this.config.redis.port
                }
            });

            this.redisClient.on('error', (err) => {
                console.error('Redis Client Error:', err);
            });

            await this.redisClient.connect();
            console.log('✅ Connected to Redis');

            // Initialize Vault client
            this.vaultClient = axios.create({
                baseURL: this.config.vault.addr,
                headers: {
                    'X-Vault-Token': this.config.vault.token
                },
                httpsAgent: new https.Agent({
                    rejectUnauthorized: false
                })
            });

            this.setupRoutes();
            this.startQueueProcessor();
            this.startServer();

        } catch (error) {
            console.error('❌ Initialization failed:', error);
            process.exit(1);
        }
    }

    setupRoutes() {
        // Health check endpoint
        this.app.get('/health', (req, res) => {
            res.json({
                status: 'healthy',
                timestamp: new Date().toISOString(),
                redis: this.redisClient.isReady ? 'connected' : 'disconnected',
                queue_length: 0 // Will be updated by queue processor
            });
        });

        // Main trigger endpoint - just queues jobs
        this.app.post('/trigger', async (req, res) => {
            try {
                const jobId = `dr-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
                const parameters = req.body.parameters || {};
                
                // Create job for queue
                const drJob = {
                    id: jobId,
                    timestamp: new Date().toISOString(),
                    parameters: {
                        deploy_standby_only: parameters.deploy_standby_only || 'false',
                        destroy_after_apply: parameters.destroy_after_apply || 'false',
                        skip_tests: parameters.skip_tests || 'false'
                    },
                    source: req.headers['user-agent'] || 'api',
                    status: 'queued'
                };

                // Add to Redis queue
                await this.redisClient.lPush('dr-queue', JSON.stringify(drJob));
                
                console.log(`📝 DR job queued: ${jobId}`, drJob.parameters);

                res.json({
                    statusCode: 200,
                    message: 'DR job queued successfully',
                    job_id: jobId,
                    parameters: drJob.parameters,
                    queue_position: await this.redisClient.lLen('dr-queue')
                });

            } catch (error) {
                console.error('❌ Trigger failed:', error);
                res.status(500).json({
                    error: 'Trigger execution failed',
                    message: error.message
                });
            }
        });

        // Queue status endpoint
        this.app.get('/queue/status', async (req, res) => {
            try {
                const queueLength = await this.redisClient.lLen('dr-queue');
                const processingLength = await this.redisClient.lLen('dr-processing');
                
                res.json({
                    queued: queueLength,
                    processing: processingLength,
                    timestamp: new Date().toISOString()
                });
            } catch (error) {
                res.status(500).json({ error: error.message });
            }
        });

        // Job status endpoint
        this.app.get('/job/:jobId/status', async (req, res) => {
            try {
                const jobId = req.params.jobId;
                const jobStatus = await this.redisClient.hGet('jenkins_jobs', jobId);
                
                if (jobStatus) {
                    res.json(JSON.parse(jobStatus));
                } else {
                    res.status(404).json({ error: 'Job not found' });
                }
            } catch (error) {
                res.status(500).json({ error: error.message });
            }
        });
    }

    // Separate queue processor - runs continuously
    async startQueueProcessor() {
        console.log('🔄 Starting queue processor...');
        
        setImmediate(async () => {
            while (true) {
                try {
                    // Non-blocking check for jobs
                    const jobData = await this.redisClient.brPop('dr-queue', 5); // 5 second timeout
                    
                    if (jobData) {
                        const { element: jobJson } = jobData;
                        const job = JSON.parse(jobJson);
                        
                        console.log(`🚀 Processing DR job: ${job.id}`);
                        
                        // Move to processing queue
                        await this.redisClient.lPush('dr-processing', jobJson);
                        
                        // Trigger Jenkins webhook
                        await this.triggerJenkinsWebhook(job);
                        
                        // Remove from processing queue (job is now in Jenkins)
                        await this.redisClient.lRem('dr-processing', 1, jobJson);
                        
                    } else {
                        // No jobs - brief pause before next check
                        await new Promise(resolve => setTimeout(resolve, 1000));
                    }
                    
                } catch (error) {
                    console.error('❌ Queue processor error:', error);
                    await new Promise(resolve => setTimeout(resolve, 5000));
                }
            }
        });
    }

    async triggerJenkinsWebhook(job) {
        try {
            // Get webhook configuration from Vault
            const { webhookUrl, webhookToken } = await this.getWebhookFromVault();
            
            // Prepare webhook payload for Generic Webhook Trigger plugin
            const payload = {
                parameters: job.parameters
            };
            
            console.log(`📡 Triggering Jenkins webhook for job ${job.id}`);
            console.log(`🎯 Webhook URL: ${webhookUrl}`);
            console.log(`📋 Parameters:`, job.parameters);
            
            // Make HTTP POST to Jenkins webhook
            const response = await axios.post(webhookUrl, payload, {
                headers: {
                    'Content-Type': 'application/json'
                },
                timeout: 30000,
                httpsAgent: new https.Agent({
                    rejectUnauthorized: false
                })
            });
            
            if (response.status >= 200 && response.status < 300) {
                console.log(`✅ Successfully triggered Jenkins job ${job.id}`);
                
                // Update job status
                const jobUpdate = {
                    ...job,
                    status: 'triggered',
                    jenkins_triggered_at: new Date().toISOString(),
                    jenkins_response_status: response.status
                };
                
                await this.redisClient.hSet('jenkins_jobs', job.id, JSON.stringify(jobUpdate));
                
            } else {
                throw new Error(`Jenkins returned status ${response.status}`);
            }
            
        } catch (error) {
            console.error(`❌ Failed to trigger Jenkins for job ${job.id}:`, error.message);
            
            // Update job status with error
            const jobUpdate = {
                ...job,
                status: 'failed',
                error: error.message,
                failed_at: new Date().toISOString()
            };
            
            await this.redisClient.hSet('jenkins_jobs', job.id, JSON.stringify(jobUpdate));
        }
    }

    async getWebhookFromVault() {
        try {
            const response = await this.vaultClient.get(`/v1/secret/data/jenkins/${this.config.jenkins.pipeline_name}`);
            const data = response.data.data.data;
            
            return {
                webhookUrl: data.webhook_url,
                webhookToken: data.webhook_token
            };
        } catch (error) {
            console.error('❌ Failed to retrieve webhook config from Vault:', error.message);
            throw error;
        }
    }

    startServer() {
        this.app.listen(this.config.server.port, this.config.server.host, () => {
            console.log(`🚀 Node.js Trigger Service running on ${this.config.server.host}:${this.config.server.port}`);
            console.log(`📍 Endpoints:`);
            console.log(`   Health: GET /health`);
            console.log(`   Trigger: POST /trigger`);
            console.log(`   Queue Status: GET /queue/status`);
            console.log(`   Job Status: GET /job/:jobId/status`);
        });
    }

    async shutdown() {
        console.log('🔄 Shutting down Node.js Trigger Service...');
        
        if (this.redisClient) {
            await this.redisClient.disconnect();
        }
        
        process.exit(0);
    }
}

// Handle shutdown signals
process.on('SIGINT', async () => {
    if (global.triggerService) {
        await global.triggerService.shutdown();
    }
});

process.on('SIGTERM', async () => {
    if (global.triggerService) {
        await global.triggerService.shutdown();
    }
});

// Start the service
if (require.main === module) {
    global.triggerService = new StreamlinedNodeJSTrigger();
}

module.exports = StreamlinedNodeJSTrigger;