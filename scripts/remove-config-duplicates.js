#!/usr/bin/env node

/**
 * BytEM Configuration Duplicate Remover
 * 
 * Removes duplicate variable definitions from configuration files,
 * keeping the last occurrence of each variable.
 * 
 * Usage: node scripts/remove-config-duplicates.js [file1] [file2] ...
 *        node scripts/remove-config-duplicates.js --all
 */

const fs = require('fs');
const path = require('path');

/**
 * Remove duplicates from a single configuration file
 */
function removeDuplicatesFromFile(filePath) {
  console.log(`🔧 Processing ${path.basename(filePath)}...`);
  
  if (!fs.existsSync(filePath)) {
    console.log(`⚠ File not found: ${filePath}`);
    return false;
  }
  
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    
    // Track variables and their last occurrence
    const variableMap = new Map();
    const processedLines = [];
    const duplicatesFound = new Set();
    
    // First pass: identify all variables and their positions
    lines.forEach((line, index) => {
      const trimmedLine = line.trim();
      
      // Check if line is a variable definition
      const match = trimmedLine.match(/^([A-Z_][A-Z0-9_]*)=(.*)$/);
      
      if (match) {
        const variableName = match[1];
        const variableValue = match[2];
        
        // If we've seen this variable before, mark previous occurrence as duplicate
        if (variableMap.has(variableName)) {
          duplicatesFound.add(variableName);
          // Mark previous occurrence for removal
          const previousIndex = variableMap.get(variableName).index;
          lines[previousIndex] = ''; // Mark for removal
        }
        
        // Store current occurrence
        variableMap.set(variableName, {
          index,
          value: variableValue,
          line: line
        });
      }
    });
    
    // Second pass: build clean content
    const cleanLines = lines.filter(line => line !== '');
    
    // Remove consecutive empty lines (keep max 2)
    const finalLines = [];
    let emptyLineCount = 0;
    
    cleanLines.forEach(line => {
      if (line.trim() === '') {
        emptyLineCount++;
        if (emptyLineCount <= 2) {
          finalLines.push(line);
        }
      } else {
        emptyLineCount = 0;
        finalLines.push(line);
      }
    });
    
    const cleanContent = finalLines.join('\n');
    
    if (duplicatesFound.size > 0) {
      // Create backup
      const backupPath = `${filePath}.backup.${Date.now()}`;
      fs.copyFileSync(filePath, backupPath);
      
      // Write cleaned content
      fs.writeFileSync(filePath, cleanContent);
      
      console.log(`✅ Removed ${duplicatesFound.size} duplicate variables:`);
      duplicatesFound.forEach(variable => {
        const finalValue = variableMap.get(variable).value;
        console.log(`  • ${variable}=${finalValue}`);
      });
      console.log(`📋 Backup created: ${path.basename(backupPath)}`);
      
      return true;
    } else {
      console.log(`✓ No duplicates found in ${path.basename(filePath)}`);
      return false;
    }
    
  } catch (error) {
    console.error(`❌ Error processing ${filePath}: ${error.message}`);
    return false;
  }
}

/**
 * Remove duplicates from all configuration files
 */
function removeAllDuplicates() {
  console.log('🔧 Removing duplicates from all configuration files...\n');
  
  const configDir = path.join(__dirname, '..', 'config');
  const configFiles = [
    'bytem-template.env',
    'bytem1.env',
    'bytem2.env',
    'bytem3.env',
    'bytem4.env'
  ];
  
  let totalProcessed = 0;
  let totalCleaned = 0;
  
  configFiles.forEach(filename => {
    const filePath = path.join(configDir, filename);
    if (fs.existsSync(filePath)) {
      totalProcessed++;
      if (removeDuplicatesFromFile(filePath)) {
        totalCleaned++;
      }
      console.log(''); // Empty line between files
    }
  });
  
  console.log(`📊 Summary: Cleaned ${totalCleaned}/${totalProcessed} files`);
  return totalCleaned;
}

/**
 * Main function
 */
function main() {
  const args = process.argv.slice(2);
  
  console.log('🧹 BytEM Configuration Duplicate Remover');
  console.log('========================================\n');
  
  if (args.length === 0 || args[0] === '--help') {
    console.log('💡 Usage:');
    console.log('  node scripts/remove-config-duplicates.js --all');
    console.log('  node scripts/remove-config-duplicates.js config/bytem1.env');
    console.log('  node scripts/remove-config-duplicates.js config/*.env');
    console.log('');
    console.log('🔧 Features:');
    console.log('  • Keeps the last occurrence of each variable');
    console.log('  • Creates automatic backups');
    console.log('  • Preserves comments and structure');
    console.log('  • Removes excessive empty lines');
    return;
  }
  
  if (args[0] === '--all') {
    removeAllDuplicates();
  } else {
    // Process specific files
    let totalCleaned = 0;
    args.forEach(filePath => {
      if (removeDuplicatesFromFile(filePath)) {
        totalCleaned++;
      }
      console.log('');
    });
    console.log(`📊 Summary: Cleaned ${totalCleaned}/${args.length} files`);
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  removeDuplicatesFromFile,
  removeAllDuplicates
};
