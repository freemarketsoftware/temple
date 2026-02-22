#!/usr/bin/env python3
"""
Test crash recovery.
Deliberately crashes TempleOS with Panic(), then verifies recover() restores
the system to a working state.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from temple import Temple

def main():
    print("=== Crash Recovery Test ===\n")

    with Temple() as t:
        # 1. Freeze
        print("[1] Freezing...")
        t.freeze()
        assert t.is_frozen(), "FAIL: not frozen after freeze()"
        print("    OK: frozen\n")

        # 2. Confirm baseline works
        print("[2] Baseline check...")
        result = t.exec_str('GStrAdd("alive");')
        assert result == "alive", f"FAIL: got {result!r}"
        print(f"    OK: '{result}'\n")

        # 3. Trigger hang — infinite loop makes REPL go silent permanently
        print("[3] Triggering hang via infinite loop...")
        result = t.send_cmd('while(1);', timeout=5)
        print(f"    send_cmd returned: {result!r}  (None = REPL hung = crash detected)")
        assert result is None, f"FAIL: expected None, got {result!r}"
        print("    OK: hang detected\n")

        # 4. Confirm REPL is non-responsive
        print("[4] Confirming REPL is dead...")
        assert not t.is_frozen(timeout=2), "FAIL: REPL still responding after infinite loop?"
        print("    OK: REPL confirmed dead\n")

        # 5. Recover
        print("[5] Recovering (loadvm snap1 + re-freeze)...")
        t.recover()
        print("    recover() complete\n")

        # 6. Confirm REPL is back
        print("[6] Confirming REPL is alive...")
        assert t.is_frozen(), "FAIL: not frozen after recover()"
        print("    OK: frozen\n")

        # 7. Confirm execution works
        print("[7] Post-recovery execution check...")
        result = t.exec_str('GStrAdd("survived");')
        assert result == "survived", f"FAIL: got {result!r}"
        print(f"    OK: '{result}'\n")

        print("[unfreeze]")
        t.unfreeze()

    print("=== PASS: crash recovery works ===")

if __name__ == '__main__':
    main()
