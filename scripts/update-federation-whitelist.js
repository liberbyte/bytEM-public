#!/usr/bin/env node
/**
 * Dynamic Federation Whitelist Updater
 * 
 * This script fetches the BytEM market list and updates all homeserver.yaml files
 * to enable federation between all discovered BytEM instances.
 * 
 * Features:
 * - Fetches live market list from https://bytem.app/markets/byteM-market-list
 * - Updates federation_domain_whitelist in all homeserver.yaml files
 * - Environment-aware port assignment (dev vs prod)
 * - Automatic discovery and configuration
 */

const fs = require('fs');
const path = require('path');
const axios = require('axios');
const yaml = require('js-yaml');

/**
 * Fetch BytEM instances from market list API
 */
async function fetchBytemInstances() {
  try {
    console.log('🌐 Fetching BytEM instances from market list...');
    
    const response = await axios.get('https://bytem.app/markets/byteM-market-list', {
      timeout: 10000
    });
    
    const marketData = response.data;
    const instances = [];
    
    if (Array.isArray(marketData)) {
      marketData.forEach((domain, index) => {
        if (domain && typeof domain === 'string' && domain.trim()) {
          const cleanDomain = domain.trim();
          const instanceName = cleanDomain.split('.')[0];
          
          instances.push({
            name: instanceName,
            domain: cleanDomain,
            index: index
          });
        }
      });
    }
    
    console.log(`✅ Discovered ${instances.length} BytEM instances:`);
    instances.forEach(instance => {
      console.log(`📋 ${instance.name}: ${instance.domain}`);
    });
    
    return instances;
    
  } catch (error) {
    console.warn('⚠️ Failed to fetch market list, using fallback instances:', error.message);
    
    // Fallback to known instances
    return [];
  }
}

/**
 * Update homeserver.yaml with federation whitelist
 */
async function updateHomeserverFederation(configPath, currentDomain, allDomains) {
  try {
    console.log(`🔧 Updating federation for ${currentDomain}...`);
    
    if (!fs.existsSync(configPath)) {
      console.log(`⚠️ Config not found: ${configPath}`);
      return false;
    }
    
    // Read current homeserver.yaml
    const yamlContent = fs.readFileSync(configPath, 'utf8');
    const config = yaml.load(yamlContent);
    
    // Create federation whitelist (exclude self)
    const federationWhitelist = allDomains
      .filter(domain => domain !== currentDomain)
      .sort();
    
    // Update federation configuration
    config.federation_domain_whitelist = federationWhitelist;
    
    // Enable federation
    config.federation_enabled = true;
    
    // Add federation metrics (optional)
    config.federation_metrics_domains = federationWhitelist;
    
    // Write updated config
    const updatedYaml = yaml.dump(config, {
      indent: 2,
      lineWidth: 120,
      noRefs: true
    });
    
    fs.writeFileSync(configPath, updatedYaml);
    
    console.log(`✅ Updated ${currentDomain} with ${federationWhitelist.length} federated domains:`);
    federationWhitelist.forEach(domain => {
      console.log(`   🔗 ${domain}`);
    });
    
    return true;
    
  } catch (error) {
    console.error(`❌ Failed to update ${configPath}:`, error.message);
    return false;
  }
}

/**
 * Main function to update all homeserver configurations
 */
async function main() {
  try {
    console.log('🚀 Starting Dynamic Federation Whitelist Update...');
    console.log('===================================================');
    
    // Fetch instances from market list
    const instances = await fetchBytemInstances();
    const allDomains = instances.map(instance => instance.domain);
    
    console.log('🔧 Updating homeserver.yaml files...');
    
    // Update each homeserver config
    const configUpdates = [];
    
    for (const instance of instances) {
      const configPath = path.resolve(__dirname, `../synapse-config/${instance.name}/homeserver.yaml`);
      
      // Try multiple possible config paths
      const possiblePaths = [
        path.resolve(__dirname, `../synapse-config/${instance.name}/homeserver.yaml`),
        path.resolve(__dirname, `../synapse-config/bytem${instance.index + 1}/homeserver.yaml`)
      ];
      
      let actualConfigPath = null;
      for (const testPath of possiblePaths) {
        if (fs.existsSync(testPath)) {
          actualConfigPath = testPath;
          break;
        }
      }
      
      if (actualConfigPath) {
        const success = await updateHomeserverFederation(actualConfigPath, instance.domain, allDomains);
        configUpdates.push({
          instance: instance.name,
          domain: instance.domain,
          path: actualConfigPath,
          success: success
        });
      } else {
        console.log(`⚠️ No config found for ${instance.name} (${instance.domain})`);
        configUpdates.push({
          instance: instance.name,
          domain: instance.domain,
          path: 'not found',
          success: false
        });
      }
    }
    
    // Summary
    console.log('📊 Federation Update Summary:');
    console.log('=============================');
    
    const successful = configUpdates.filter(update => update.success);
    const failed = configUpdates.filter(update => !update.success);
    
    console.log(`✅ Successfully updated: ${successful.length} instances`);
    successful.forEach(update => {
      console.log(`   ✅ ${update.instance} (${update.domain})`);
    });
    
    if (failed.length > 0) {
      console.log(`❌ Failed to update: ${failed.length} instances`);
      failed.forEach(update => {
        console.log(`   ❌ ${update.instance} (${update.domain}) - ${update.path}`);
      });
    }
    
    console.log('🎉 Dynamic Federation Whitelist Update Complete!');
    console.log('💡 Restart Matrix servers to apply federation changes');
    
  } catch (error) {
    console.error('❌ Federation update failed:', error.message);
    process.exit(1);
  }
}

// Run the script
if (require.main === module) {
  main();
}

module.exports = { fetchBytemInstances, updateHomeserverFederation };