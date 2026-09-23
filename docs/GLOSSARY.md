# Glossary

| Term | Meaning |
| --- | --- |
| Beamlet | Native controller app; not the agent or remote transport. |
| Server | One app-owned `claude remote-control` process. It may serve several conversations according to Claude's defaults. |
| Session | A Claude conversation reachable from a session URL. Not synonymous with the server process. |
| Starting folder | Working directory passed when starting the server. Changes do not silently restart it. |
| Registered | CLI has produced a valid session URL; not perpetual proof of connectivity. |
| Online | A currently evidenced usable connection; never inferred solely from a live PID. |
| Reconnecting | Connectivity is interrupted and the CLI or Beamlet is attempting bounded recovery. |
| Setup required | Missing login, trust, consent, supported CLI, or executable; needs user action. |
| Owned process | Process launched by this live Beamlet instance and tracked by its transport handle/generation. |
| External process | Any process not owned by this Beamlet instance; never stopped by Beamlet. |
| Stop | Cancel recovery and send normal interrupt to the owned server. Does not promise transcript deletion. |
| Keep awake | Prevent idle system sleep on AC power while running, not a closed-lid guarantee. |
| Appcast | Sparkle's published update feed, with signed release metadata/archive references. |
