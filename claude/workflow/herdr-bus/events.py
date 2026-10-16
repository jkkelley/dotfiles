#!/usr/bin/env python3
"""Subscribe to herdr's socket event stream and print one line per event that should trigger a reconcile.

usage: events.py <socket> <pane_id>...
Exits (so the shell loop resubscribes with a fresh pane list) on a structural event, events_lost, or EOF.
BREADCRUMB - why a subscriber and not a poll: herdr 0.9.5 pushes pane.agent_status_changed over events.subscribe
  (docs socket-api.mdx "Event subscriptions"), so a change reaches NATS in well under a second and a quiet herdr costs
  nothing. The plugin manifest hooks were rejected: they cover lifecycle events only, not agent status.
  Cost: status subscriptions need a pane_id each, so a new pane means resubscribing; that is the exit-on-structural path.
"""
import json, socket, sys

STRUCTURAL = {"pane.created", "pane.closed", "pane.exited", "pane.agent_detected", "tab.created", "tab.closed"}

def main(sock_path, panes):
    subs = [{"type": "pane.agent_status_changed", "pane_id": p} for p in panes]
    subs += [{"type": t} for t in sorted(STRUCTURAL)]
    s = socket.socket(socket.AF_UNIX)
    s.connect(sock_path)
    s.sendall((json.dumps({"id": "herdr-bus", "method": "events.subscribe", "params": {"subscriptions": subs}}) + "\n").encode())
    buf = b""
    while True:
        data = s.recv(65536)
        if not data:
            print("eof", flush=True); return 0
        buf += data
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            try:
                msg = json.loads(line)
            except ValueError:
                continue
            if "error" in msg:
                print("error " + str(msg["error"].get("code", "")), flush=True); return 0
            # Wire shapes seen on herdr 0.9.5: {"id":..,"result":{"type":"subscription_started"}} for the ack, then
            # {"event":"pane_created","data":{"type":"pane.created",...}} per event. Normalise to dotted names.
            res = msg.get("result")
            t = (res.get("type", "") if isinstance(res, dict) else "") or (msg.get("data") or {}).get("type", "") \
                or str(msg.get("event", "")).replace("_", ".", 1)
            if t == "subscription_started":
                print("ready", flush=True)
            elif t in STRUCTURAL:
                print("structural " + t, flush=True); return 0
            elif t:
                print("event " + t, flush=True)

if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2:]))
