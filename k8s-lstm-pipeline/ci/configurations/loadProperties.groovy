P#!/usr/bin/env groovy

/**
 * Helper function to load properties from file
 * Allows external configuration similar to Ansible defaults/main.yml
 */
def call(String propertiesFile) {
    def props = [:]
    
    // Check if properties file exists
    if (fileExists(propertiesFile)) {
        def content = readFile(file: propertiesFile).trim()
        
        // Process each line
        content.split("\n").each { line ->
            line = line.trim()
            // Skip comments and empty lines
            if (line && !line.startsWith('#')) {
                def parts = line.split('=', 2)
                if (parts.length == 2) {
                    def key = parts[0].trim()
                    def value = parts[1].trim()
                    
                    // Remove quotes if present
                    if ((value.startsWith('"') && value.endsWith('"')) || 
                        (value.startsWith("'") && value.endsWith("'"))) {
                        value = value.substring(1, value.length() - 1)
                    }
                    
                    props[key] = value
                }
            }
        }
    }
    
    return props
}

return this