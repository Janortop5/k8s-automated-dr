const express = require('express');
const redis = require('redis');
const axios = require('axios');
const https = require('https');
const fs = require('fs');
const path = require('path');

class NodeJSTrigger {
    constructor() {
        this.app = express();
        this.redisClient = null;
        this.vaultClient = null;
        this.config = this.loadConfig();
        
        // Setup middleware
        this.app.use(express.json());
        this.app.use(express.urlencoded({ extended: true }));
        
        // Initialize connections
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
                pipeline_name: process.env.PIPELINE_NAME || 'Pipeline',
                branch_name: process.env.BRANCH_NAME || 'main'
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
            console.log('Connected to Redis');

            // Initialize Vault client
            this.vaultClient = axios.create({
                baseURL: this.config.vault.addr,
                headers: {
                    'X-Vault-Token': this.config.vault.token
                },
                // Disable SSL verification for self-signed certificates (like Lambda)
                httpsAgent: new https.Agent({
                    rejectUnauthorized: false
                })
            });

            this.setupRoutes();
            this.startServer();

        } catch (error) {
            console.error('Initialization failed:', error);
            process.exit(1);
        }
    }

    async getSecretsFromVault() {
        try {
            // Retrieve Jenkins credentials from Vault
            const jenkinsCredsResponse = await this.vaultClient.get('/v1/secret/data/jenkins');
            const jenkinsUser = jenkinsCredsResponse.data.data.data.username;
            const jenkinsApiToken = jenkinsCredsResponse.data.data.data.api_token;

            return { jenkinsUser, jenkinsApiToken };
        } catch (error) {
            console.error('Failed to retrieve secrets from Vault:', error.message);
            throw error;
        }
    }

    setupRoutes() {
        // Health check endpoint
        this.app.get('/health', (req, res) => {
            res.json({
                status: 'healthy',
                timestamp: new Date().toISOString(),
                redis: this.redisClient.isReady ? 'connected' : 'disconnected'
            });
        });

        // Main trigger endpoint (replaces Lambda handler)
        this.app.post('/trigger', async (req, res) => {
            try {
                const result = await this.handleTrigger(req.body);
                res.json(result);
            } catch (error) {
                console.error('Trigger failed:', error);
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
    }

    async handleTrigger(eventData) {
        // Extract parameters (same logic as Lambda)
        const parameters = eventData.parameters || {};
        
        // Default parameters matching Lambda function
        const buildParams = {
            'DEPLOY_STANDBY_ONLY': parameters.deploy_standby_only || 'false',
            'DESTROY_AFTER_APPLY': parameters.destroy_after_apply || 'false',
            'SKIP_TESTS': parameters.skip_tests || 'false'
        };

        // Create DR job payload
        const drJob = {
            id: `dr-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
            timestamp: new Date().toISOString(),
            parameters: buildParams,
            pipeline_name: this.config.jenkins.pipeline_name,
            branch_name: this.config.jenkins.branch_name,
            source: 'nodejs-trigger',
            status: 'queued'
        };

        // Queue the job in Redis instead of directly calling Jenkins
        await this.redisClient.lPush('dr-queue', JSON.stringify(drJob));

        console.log(`DR job queued: ${drJob.id}`, buildParams);

        return {
            statusCode: 200,
            message: 'DR job queued successfully',
            job_id: drJob.id,
            parameters: buildParams,
            queue_position: await this.redisClient.lLen('dr-queue')
        };
    }

    // Optional: Direct Jenkins trigger method (for testing/fallback)
    async triggerJenkinsDirectly(buildParams) {
        try {
            const { jenkinsUser, jenkinsApiToken } = await this.getSecretsFromVault();
            
            // Create authentication header (same as Lambda)
            const credentials = `${jenkinsUser}:${jenkinsApiToken}`;
            const encodedCredentials = Buffer.from(credentials).toString('base64');
            
            const headers = {
                'Authorization': `Basic ${encodedCredentials}`,
                'Content-Type': 'application/x-www-form-urlencoded'
            };

            // Build Jenkins URL (same as Lambda)
            const jenkinsUrl = `${this.config.jenkins.url}/job/${this.config.jenkins.pipeline_name}/job/${this.config.jenkins.branch_name}/buildWithParameters`;
            
            // Create form data
            const formData = new URLSearchParams(buildParams).toString();

            // Make request with axios instead of urllib3
            const response = await axios.post(jenkinsUrl, formData, {
                headers,
                httpsAgent: new https.Agent({
                    rejectUnauthorized: false // Same as Lambda's SSL handling
                })
            });

            if (response.status === 201) {
                return {
                    success: true,
                    jenkins_url: jenkinsUrl,
                    parameters: buildParams,
                    queue_location: response.headers.location || ''
                };
            } else {
                throw new Error(`Jenkins returned status ${response.status}`);
            }

        } catch (error) {
            console.error('Direct Jenkins trigger failed:', error.message);
            throw error;
        }
    }

    startServer() {
        this.app.listen(this.config.server.port, this.config.server.host, () => {
            console.log(`Node.js Trigger Service running on ${this.config.server.host}:${this.config.server.port}`);
            console.log(`Queue endpoint: POST /trigger`);
            console.log(`Health check: GET /health`);
            console.log(`Queue status: GET /queue/status`);
        });
    }

    // Graceful shutdown
    async shutdown() {
        console.log('Shutting down Node.js Trigger Service...');
        
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
    global.triggerService = new NodeJSTrigger();
}

module.exports = NodeJSTrigger;