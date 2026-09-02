// Command nixfleet is the nixfleet CLI (M0: status against the API).
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"nixfleet/shared/version"
)

func main() {
	// Accept both `nixfleet status --api URL` and `nixfleet --api URL status`.
	// flag stops at the first non-flag token, so peel a leading subcommand off.
	sub := ""
	rest := os.Args[1:]
	if len(rest) > 0 && !strings.HasPrefix(rest[0], "-") {
		sub = rest[0]
		rest = rest[1:]
	}
	fs := flag.NewFlagSet("nixfleet", flag.ExitOnError)
	api := fs.String("api", "http://localhost:8443", "nixfleet API base URL")
	showVersion := fs.Bool("version", false, "print version and exit")
	fs.Parse(rest)

	if *showVersion {
		log.Println(version.String())
		return
	}

	cmd := sub
	if cmd == "" && fs.NArg() > 0 {
		cmd = fs.Arg(0)
	}
	switch cmd {
	case "", "status":
		if err := status(*api); err != nil {
			log.Fatal(err)
		}
	case "health":
		if err := health(*api); err != nil {
			log.Fatal(err)
		}
	default:
		fmt.Fprintf(os.Stderr, "usage: nixfleet [status|health] [--api URL]\n")
		os.Exit(2)
	}
}

func health(api string) error {
	resp, err := http.Get(api + "/api/v1/health")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return err
	}
	ok, _ := body["ok"].(bool)
	if !ok {
		return fmt.Errorf("API unhealthy")
	}
	fmt.Printf("API %v @ %s\n", body["version"], api)
	return nil
}

func status(api string) error {
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(api + "/api/v1/meta")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	var meta map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&meta); err != nil {
		return err
	}
	manifest, ok := meta["manifest"].(map[string]any)
	if !ok {
		return fmt.Errorf("no manifest in meta response")
	}
	hosts, _ := manifest["hosts"].(map[string]any)
	fmt.Printf("nixfleet: %d hosts in manifest\n", len(hosts))
	return nil
}
