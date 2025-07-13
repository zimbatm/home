const cp = require('child_process');
const fs = require('fs');

// Store original functions before patching
const originalSpawn = cp.spawn;
const originalExec = cp.exec;
const originalExecSync = cp.execSync;
const originalExecFile = cp.execFile;

// ANSI color constants
const colors = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  grey: '\x1b[90m',
  reset: '\x1b[0m'
};

// Track if we've created the right pane yet
let rightPaneCreated = false;

// Error handler that displays in Claude's UI
function handleError(error, context) {
  const errorMsg = `[claudebox error in ${context}]: ${error.message || error}`;
  console.error(errorMsg);
  // Also try to show in the command pane if it exists
  if (rightPaneCreated) {
    appendToLog(`\n❌ ${errorMsg}\n`);
  }
}

// Helper to capture and log output from child processes
function wrapChildProcess(child, command) {
  if (!child || !child.stdout || !child.stderr) return child;
  
  // Capture stdout
  child.stdout.on('data', (data) => {
    const output = data.toString();
    if (output) {
      appendToLog(output);
    }
  });
  
  // Capture stderr
  child.stderr.on('data', (data) => {
    const output = data.toString();
    if (output) {
      appendToLog(`${colors.red}${output}${colors.reset}`);
    }
  });
  
  // Log exit code
  child.on('exit', (code) => {
    if (code !== 0) {
      appendToLog(`${colors.red}✗ Exit code: ${code}${colors.reset}\n`);
    }
  });
  
  return child;
}

function parseCommand(command) {
  // Extract the actual command from Claude's bash wrapper
  // Pattern: bash -c -l eval 'ACTUAL_COMMAND' < /dev/null && pwd -P >| /tmp/...
  const evalMatch = command.match(/eval\s+'([^']+)'/);
  
  return {
    actualCommand: evalMatch ? evalMatch[1] : command,
    isWrapped: !!evalMatch
  };
}

const commandLog = `/tmp/claudebox-commands-${process.env.SESSION_NAME || 'unknown'}.log`;

// Initialize the command log file immediately
try {
  fs.writeFileSync(commandLog, '=== Command Output ===\n');
} catch (e) {
  // Ignore errors
}

// Helper function to safely append to log file
function appendToLog(content, ensureNewline = false) {
  try {
    fs.appendFileSync(commandLog, content);
    if (ensureNewline && content && !content.endsWith('\n')) {
      fs.appendFileSync(commandLog, '\n');
    }
  } catch (e) {
    // Ignore if file doesn't exist or other errors
  }
}

function ensureRightPane() {
  if (rightPaneCreated) return;
  
  const sessionName = process.env.SESSION_NAME || 'claude';
  
  try {
    // Create the right pane with tail following the command log from the beginning
    originalExecSync(`tmux split-window -h -t ${sessionName} "tail -f -n +1 ${commandLog}"`, { stdio: 'pipe' });
    // Return focus to the left pane
    originalExecSync(`tmux select-pane -t ${sessionName}:0.0`, { stdio: 'pipe' });
    rightPaneCreated = true;
  } catch (error) {
    handleError(error, 'ensureRightPane');
  }
}

function logCommand(command, source = '') {
  try {
    const { actualCommand, isWrapped } = parseCommand(command);
    
    // Skip empty commands
    if (!actualCommand || actualCommand.trim() === '') return;
    
    // Only create the right pane on the first wrapped command
    if (isWrapped && !rightPaneCreated) {
      ensureRightPane();
    }
    
    // Format timestamp in shorter format
    const now = new Date();
    const timestamp = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
    
    // Create fake PS1 prompt - green for wrapped commands, grey for others
    const promptColor = isWrapped ? colors.green : colors.grey;
    const commandColor = isWrapped ? '' : colors.grey;
    
    // Add source info for non-wrapped commands
    const sourceInfo = !isWrapped && source ? `[${source}] ` : '';
    
    const prompt = `${promptColor}[${timestamp}] ${sourceInfo}$ ${colors.reset}`;
    const commandLine = `${prompt}${commandColor}${actualCommand}${colors.reset}\n`;
    
    // Append to the command log file
    appendToLog(commandLine);
  } catch (error) {
    handleError(error, 'logCommand');
  }
}

// Wrap all patches in try-catch to ensure Claude continues to work even if our wrapper fails
try {
  // Patch spawn
  cp.spawn = function (cmd, args = [], options) {
    const fullCommand = [cmd, ...args].map(String).join(' ');
    logCommand(fullCommand, 'spawn');
    const child = originalSpawn.call(this, cmd, args, options);
    return wrapChildProcess(child, fullCommand);
  };

  // Patch exec
  cp.exec = function (command, options, callback) {
    // Handle different argument patterns
    if (typeof options === 'function') {
      callback = options;
      options = undefined;
    }
    logCommand(command, 'exec');
    const child = originalExec.call(this, command, options, callback);
    return wrapChildProcess(child, command);
  };

  // Patch execSync
  cp.execSync = function (command, options) {
    logCommand(command, 'execSync');
    
    let result;
    let exitCode = 0;
    try {
      result = originalExecSync.call(this, command, options);
      // Log successful output
      if (result) {
        const output = result.toString();
        if (output) {
          appendToLog(output, true);
        }
      }
    } catch (error) {
      exitCode = error.status || 1;
      // Log error output
      if (error.stderr) {
        const stderr = error.stderr.toString();
        appendToLog(`${colors.red}${stderr}${colors.reset}`, true);
      }
      appendToLog(`${colors.red}✗ Exit code: ${exitCode}${colors.reset}\n`);
      throw error; // Re-throw the original error
    }
    
    return result;
  };

  // Patch execFile
  cp.execFile = function (file, args, options, callback) {
    // Handle various argument patterns for execFile
    let actualArgs = [];
    
    if (typeof args === 'function') {
      actualArgs = [];
    } else if (Array.isArray(args)) {
      actualArgs = args;
    } else if (typeof args === 'object' && args !== null && !Array.isArray(args)) {
      // args is actually options
      actualArgs = [];
    }
    
    const fullCommand = [file, ...actualArgs].map(String).join(' ');
    logCommand(fullCommand, 'execFile');
    const child = originalExecFile.apply(this, arguments);
    return wrapChildProcess(child, fullCommand);
  };
} catch (error) {
  handleError(error, 'initialization');
}
