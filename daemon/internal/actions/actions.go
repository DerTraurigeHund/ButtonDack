package actions

import (
	"fmt"
	"os/exec"
	"runtime"
	"strings"
)

// Result holds the outcome of executing an action.
type Result struct {
	Success  bool   `json:"success"`
	Output   string `json:"output"`
	ErrorMsg string `json:"error,omitempty"`
}

// Runner handles executing shell commands and simulating hotkeys.
type Runner struct{}

// NewRunner creates a new action runner.
func NewRunner() *Runner {
	return &Runner{}
}

// RunCommand executes a shell command and returns the result.
func (r *Runner) RunCommand(command string) *Result {
	if strings.TrimSpace(command) == "" {
		return &Result{Success: true, Output: "No command defined"}
	}

	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		cmd = exec.Command("cmd", "/C", command)
	} else {
		cmd = exec.Command("sh", "-c", command)
	}

	output, err := cmd.CombinedOutput()
	outStr := string(output)

	if err != nil {
		return &Result{
			Success:  false,
			Output:   outStr,
			ErrorMsg: fmt.Sprintf("command failed: %v", err),
		}
	}

	return &Result{
		Success: true,
		Output:  outStr,
	}
}

// PressHotkeys simulates pressing the given hotkey combinations.
// Each entry in the slice is a combination (e.g. ["ctrl", "alt", "s"]).
func (r *Runner) PressHotkeys(hotkeys [][]string) *Result {
	if len(hotkeys) == 0 {
		return &Result{Success: true, Output: "No hotkeys"}
	}

	switch runtime.GOOS {
	case "linux":
		return r.pressHotkeysLinux(hotkeys)
	case "windows":
		return r.pressHotkeysWindows(hotkeys)
	default:
		return &Result{Success: false, Output: "", ErrorMsg: fmt.Sprintf("unsupported OS: %s", runtime.GOOS)}
	}
}

func (r *Runner) pressHotkeysLinux(hotkeys [][]string) *Result {
	for _, combo := range hotkeys {
		// Convert ["ctrl", "alt", "s"] to "ctrl+alt+s" for xdotool
		keySeq := strings.Join(combo, "+")
		cmd := exec.Command("xdotool", "key", keySeq)
		if output, err := cmd.CombinedOutput(); err != nil {
			return &Result{
				Success:  false,
				Output:   string(output),
				ErrorMsg: fmt.Sprintf("hotkey failed (%s): %v", keySeq, err),
			}
		}
	}
	return &Result{Success: true, Output: "Hotkeys pressed"}
}

func (r *Runner) pressHotkeysWindows(hotkeys [][]string) *Result {
	// On Windows we use a PowerShell approach with Wscript.Shell
	for _, combo := range hotkeys {
		// Build a PowerShell command using SendKeys
		// Convert key names to SendKeys format
		keySeq := convertToSendKeys(combo)
		psCmd := fmt.Sprintf(`
$wshell = New-Object -ComObject wscript.shell;
$wshell.SendKeys('%s');
Start-Sleep -Milliseconds 100;
`, keySeq)
		cmd := exec.Command("powershell", "-NoProfile", "-Command", psCmd)
		if output, err := cmd.CombinedOutput(); err != nil {
			return &Result{
				Success:  false,
				Output:   string(output),
				ErrorMsg: fmt.Sprintf("hotkey failed: %v", err),
			}
		}
	}
	return &Result{Success: true, Output: "Hotkeys pressed"}
}

// convertToSendKeys converts our key format to Windows SendKeys format.
func convertToSendKeys(keys []string) string {
	var parts []string
	for _, k := range keys {
		switch strings.ToLower(k) {
		case "ctrl":
			parts = append(parts, "^")
		case "alt":
			parts = append(parts, "%")
		case "shift":
			parts = append(parts, "+")
		case "win", "super", "meta":
			parts = append(parts, "^{esc}") // approximation: Ctrl+Esc for Win key
		default:
			// Single character or special key
			if len(k) == 1 {
				parts = append(parts, strings.ToUpper(k))
			} else {
				// SendKeys wraps special keys in {}
				parts = append(parts, fmt.Sprintf("{%s}", strings.Title(k)))
			}
		}
	}
	return strings.Join(parts, "")
}
