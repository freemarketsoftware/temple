#!/usr/bin/env python3
"""
run_agent.py — Deploy AgentLoop.HC and open an interactive session.

Usage:
    sudo python3 serial/run_agent.py [--no-snap]

Delegates to agent_repl.py.  Kept as a convenience alias.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))

# Just forward to agent_repl
from agent_repl import main
main()
