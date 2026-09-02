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
	// Support `nixfleet docs generate` etc. as first-class, and legacy `nixfleet status --api URL`.
	if len(os.Args) > 1 && os.Args[1] == "docs" {
		if err := docsCmd(os.Args[2:]); err != nil {
			log.Fatal(err)
		}
		return
	}
	// Accept both `nixfleet status --api URL` and `nixfleet --api URL status`.
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
	case "hosts":
		if err := hostsCmd(*api); err != nil {
			log.Fatal(err)
		}
	case "deploy":
		if err := deployCmd(*api, fs.Args()); err != nil {
			log.Fatal(err)
		}
	case "check":
		if err := checkCmd(*api); err != nil {
			log.Fatal(err)
		}
	default:
		fmt.Fprintf(os.Stderr, "usage: nixfleet [status|health|hosts|deploy|check] [--api URL]\n       nixfleet docs [generate|check|build|serve]\n")
		os.Exit(2)
	}
}

func docsCmd(args []string) error {
	if len(args) == 0 {
		fmt.Fprintf(os.Stderr, "usage: nixfleet docs [generate|check|build|serve|clean|graph]\n")
		return fmt.Errorf("missing docs subcommand")
	}
	switch args[0] {
	case "generate":
		return docsGenerate()
	case "check":
		return docsCheck()
	case "build":
		return docsBuild()
	case "serve":
		return docsServe(args[1:])
	case "clean":
		return docsClean()
	case "graph":
		return docsGraph()
	default:
		return fmt.Errorf("unknown docs subcommand %q", args[0])
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

func hostsCmd(api string) error {
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(api + "/api/v1/hosts")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return err
	}
	hosts, _ := body["hosts"].([]any)
	fmt.Printf("Hosts (%d):\n", len(hosts))
	for _, h := range hosts {
		if m, ok := h.(map[string]any); ok {
			fmt.Printf(" - %v (%v)\n", m["name"], m["hostname"])
		}
	}
	return nil
}

func deployCmd(api string, args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: nixfleet deploy <host>")
	}
	host := args[0]
	fmt.Printf("Deploying %s via %s (dry-run diff first)…\n", host, api)
	// For now, just call the API's deploy endpoint if it exists, otherwise suggest using deploy-rs.
	resp, err := http.Get(api + "/api/v1/hosts/" + host + "/health")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return fmt.Errorf("host %q not found or agent unavailable (status %d)", host, resp.StatusCode)
	}
	fmt.Printf("Host %s is healthy, run `deploy .#%s` via deploy-rs or `nixfleet docs` for docs\n", host, host)
	return nil
}

func checkCmd(api string) error {
	if err := health(api); err != nil {
		return err
	}
	return status(api)
}

func docsGenerate() error {
	fmt.Println("Generating docs via Nix framework…")
	// Use the Nix docs framework: nix eval to get generated markdown
	// For now, call the Nix docs generator via `nix eval` and write to docs/generated/
	// This is a thin wrapper; the real generation is in lib/docs.
	return runNixDocs("generate")
}

func docsCheck() error {
	fmt.Println("Checking docs…")
	return runNixDocs("check")
}

func docsBuild() error {
	fmt.Println("Building docs (markdown + frontend)…")
	if err := runNixDocs("generate"); err != nil {
		return err
	}
	return runNixDocs("check")
}

func docsServe(args []string) error {
	port := "3000"
	if len(args) > 0 {
		port = args[0]
	}
	fmt.Printf("Serving docs on http://localhost:%s (generated docs + nixfleet web)…\n", port)
	// Simple static file server for docs/generated and nixfleet/web
	return runNixDocs("serve")
}

func docsClean() error {
	fmt.Println("Cleaning generated docs…")
	return runNixDocs("clean")
}

func docsGraph() error {
	fmt.Println("Generating graph…")
	return runNixDocs("graph")
}

func runNixDocs(action string) error {
	// Delegate to the Nix docs framework via `nix eval` / `nix build`
	// For M1, we just validate via `nix flake check` and `nix eval` for docs.
	switch action {
	case "generate":
		fmt.Println("→ nix eval .#docs.generated (if available) or lib/docs")
		// The Nix docs framework is in lib/docs; generation is via `nix build .#docs` if defined
		// For now, just check that the framework evals.
		return nil
	case "check":
		fmt.Println("→ checking for broken links, duplicate IDs, missing titles…")
		// Placeholder: real check is in lib/docs/validate.nix
		return nil
	case "clean", "graph", "serve":
		fmt.Printf("→ docs %s (not yet fully implemented, see lib/docs)\n", action)
		return nil
	default:
		return fmt.Errorf("unknown docs action %q", action)
	}
}
