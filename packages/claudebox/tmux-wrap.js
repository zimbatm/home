const cp = require('child_process');
const fs = require('fs');

// Store original functions before patching
const originalSpawn = cp.spawn;
const originalExec = cp.exec;
const originalExecSync = cp.execSync;
const originalExecFile = cp.execFile;

// Error handler that displays in Claude's UI
function handleError(error, context) {
  const errorMsg = `[claudebox error in ${context}]: ${error.message || error}`;
  console.error(errorMsg);
  // Also try to show in the command pane if it exists
  try {
    if (rightPaneCreated && commandLog) {
      fs.appendFileSync(commandLog, `\n❌ ${errorMsg}\n`);
    }
  } catch (e) {
    // Ignore errors in error handler
  }
}

// Track if we've created the right pane yet
let rightPaneCreated = false;

function quoteForBash(cmd) {
  return `'${cmd.replace(/'/g, `'\\''`)}'`;
}

// Helper to capture and log output from child processes
function wrapChildProcess(child, command) {
  if (!child || !child.stdout || !child.stderr) return child;
  
  const actualCommand = extractActualCommand(command) || command;
  
  // Capture stdout
  child.stdout.on('data', (data) => {
    try {
      if (rightPaneCreated && commandLog) {
        const output = data.toString().trim();
        if (output) {
          fs.appendFileSync(commandLog, `  → ${output}\n`);
        }
      }
    } catch (e) {
      // Ignore errors
    }
  });
  
  // Capture stderr
  child.stderr.on('data', (data) => {
    try {
      if (rightPaneCreated && commandLog) {
        const output = data.toString().trim();
        if (output) {
          fs.appendFileSync(commandLog, `  ⚠ ${output}\n`);
        }
      }
    } catch (e) {
      // Ignore errors
    }
  });
  
  // Log exit code
  child.on('exit', (code) => {
    try {
      if (rightPaneCreated && commandLog && code !== 0) {
        fs.appendFileSync(commandLog, `  ✗ Exit code: ${code}\n`);
      }
    } catch (e) {
      // Ignore errors
    }
  });
  
  return child;
}

function extractActualCommand(command) {
  // Extract the actual command from Claude's bash wrapper
  // Pattern: bash -c -l eval 'ACTUAL_COMMAND' < /dev/null && pwd -P >| /tmp/...
  const evalMatch = command.match(/eval\s+'([^']+)'/);
  if (evalMatch) {
    return evalMatch[1];
  }
  
  // If it's not wrapped, return null to filter it out
  return null;
}

const commandLog = `/tmp/claudebox-commands-${process.env.SESSION_NAME || 'unknown'}.log`;

function ensureRightPane() {
  if (rightPaneCreated) return;
  
  const sessionName = process.env.SESSION_NAME || 'claude';
  
  try {
    // Create/clear the command log
    fs.writeFileSync(commandLog, '=== Command Output ===\n');
    
    // Create the right pane with tail following the command log
    originalExecSync(`tmux split-window -h -t ${sessionName} "tail -f ${commandLog}"`, { stdio: 'pipe' });
    // Return focus to the left pane
    originalExecSync(`tmux select-pane -t ${sessionName}:0.0`, { stdio: 'pipe' });
    rightPaneCreated = true;
  } catch (error) {
    handleError(error, 'ensureRightPane');
  }
}

function sendToRightPane(command) {
  try {
    // Extract the actual command
    const actualCommand = extractActualCommand(command);
    
    // Skip if not a wrapped command
    if (!actualCommand) return;
    
    ensureRightPane();
    
    // Add timestamp to make it clearer when commands are executed
    const timestamp = new Date().toLocaleTimeString();
    const commandWithTime = `[${timestamp}] ${actualCommand}\n`;
    
    // Append to the command log file
    fs.appendFileSync(commandLog, commandWithTime);
  } catch (error) {
    handleError(error, 'sendToRightPane');
  }
}

// Wrap all patches in try-catch to ensure Claude continues to work even if our wrapper fails
try {
  // Patch spawn
  cp.spawn = function (cmd, args = [], options) {
    let fullCommand = '';
    try {
      fullCommand = [cmd, ...args].map(String).join(' ');
      sendToRightPane(fullCommand);
    } catch (error) {
      handleError(error, 'spawn patch');
    }
    const child = originalSpawn.call(this, cmd, args, options);
    return wrapChildProcess(child, fullCommand);
  };

  // Patch exec
  cp.exec = function (command, options, callback) {
    try {
      // Handle different argument patterns
      if (typeof options === 'function') {
        callback = options;
        options = undefined;
      }
      sendToRightPane(command);
    } catch (error) {
      handleError(error, 'exec patch');
    }
    const child = originalExec.call(this, command, options, callback);
    return wrapChildProcess(child, command);
  };

  // Patch execSync
  cp.execSync = function (command, options) {
    try {
      sendToRightPane(command);
    } catch (error) {
      handleError(error, 'execSync patch');
    }
    
    let result;
    let exitCode = 0;
    try {
      result = originalExecSync.call(this, command, options);
      // Log successful output
      try {
        const actualCommand = extractActualCommand(command);
        if (actualCommand && rightPaneCreated && commandLog && result) {
          const output = result.toString().trim();
          if (output) {
            fs.appendFileSync(commandLog, `  → ${output}\n`);
          }
        }
      } catch (e) {
        // Ignore logging errors
      }
    } catch (error) {
      exitCode = error.status || 1;
      // Log error output
      try {
        const actualCommand = extractActualCommand(command);
        if (actualCommand && rightPaneCreated && commandLog) {
          if (error.stderr) {
            fs.appendFileSync(commandLog, `  ⚠ ${error.stderr.toString().trim()}\n`);
          }
          fs.appendFileSync(commandLog, `  ✗ Exit code: ${exitCode}\n`);
        }
      } catch (e) {
        // Ignore logging errors
      }
      throw error; // Re-throw the original error
    }
    
    return result;
  };

  // Patch execFile
  cp.execFile = function (file, args, options, callback) {
    let fullCommand = '';
    try {
      // Handle various argument patterns for execFile
      let actualArgs = [];
      let actualOptions = options;
      let actualCallback = callback;
      
      if (typeof args === 'function') {
        actualCallback = args;
        actualArgs = [];
      } else if (Array.isArray(args)) {
        actualArgs = args;
      } else if (typeof args === 'object' && args !== null && !Array.isArray(args)) {
        // args is actually options
        actualOptions = args;
        actualArgs = [];
        if (typeof options === 'function') {
          actualCallback = options;
        }
      }
      
      fullCommand = [file, ...actualArgs].map(String).join(' ');
      sendToRightPane(fullCommand);
    } catch (error) {
      handleError(error, 'execFile patch');
    }
    const child = originalExecFile.apply(this, arguments);
    return wrapChildProcess(child, fullCommand);
  };
} catch (error) {
  handleError(error, 'initialization');
}
