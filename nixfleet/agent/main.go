// Command nixfleet-agent runs on every managed host.
package main

import (
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"nixfleet/api/runtime"
	"nixfleet/shared/version"
)

func main() {
	host := flag.String("host", osHostname(), "hostname reported to the API")
	showVersion := flag.Bool("version", false, "print version and exit")
	flag.Parse()

	if *showVersion {
		log.Println(version.String())
		return
	}
	log.Printf("%s starting agent for host %s", version.String(), *host)

	// M1: collect and log initial runtime state; keep the process alive
	// so systemd considers the service active. Future M2 will add WS
	// connection to the API.
	if sys, err := runtime.CollectSystem(); err == nil {
		log.Printf("agent %s: hostname=%s kernel=%s uptime=%ds", *host, sys.Hostname, sys.Kernel, sys.UptimeS)
	}
	if res, err := runtime.CollectResources(); err == nil {
		log.Printf("agent %s: cpu=%d mem=%d/%d (%.1f%%)", *host, res.CPU.Logical, res.Memory.Used, res.Memory.Total, res.Memory.UsedPct)
	}
	// Block until SIGTERM/SIGINT.
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)
	// Periodic heartbeat (optional, for observability)
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case sig := <-sigCh:
			log.Printf("agent %s: received %s, exiting", *host, sig)
			return
		case <-ticker.C:
			if sys, err := runtime.CollectSystem(); err == nil {
				log.Printf("agent %s: heartbeat uptime=%ds", *host, sys.UptimeS)
			}
		}
	}
}
