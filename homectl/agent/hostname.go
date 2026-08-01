package main

import (
	"os"
)

// osHostname returns the machine hostname, falling back to "unknown".
func osHostname() string {
	name, err := os.Hostname()
	if err != nil || name == "" {
		return "unknown"
	}
	return name
}
