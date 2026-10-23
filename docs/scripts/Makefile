.PHONY: youtube-vj youtube-vj-start youtube-vj-status youtube-vj-stop youtube-vj-stop-next youtube-vj-restart-next \
        convert-vj convert-vj-start convert-vj-status convert-vj-stop convert-vj-stop-next convert-vj-restart-next \
        convert-vj-splits convert-vj-splits-start convert-vj-splits-status \
        convert-vj-splits-stop convert-vj-splits-stop-next

youtube-vj youtube-vj-start:
	@./vj-background-start.sh youtube-vj "make youtube-vj-status" "$$HOME/.cache/yt-dlp/vj-batch.log" ./vj-run-limited.sh ./vj-download-all.sh

youtube-vj-status:
	@./youtube-vj-status

youtube-vj-stop:
	@./youtube-vj-stop

youtube-vj-stop-next:
	@./youtube-vj-stop-next

youtube-vj-restart-next:
	@./vj-restart-next.sh youtube-vj "make youtube-vj-status" "$$HOME/.cache/yt-dlp/vj-batch.log" ./vj-run-limited.sh ./vj-download-all.sh

convert-vj convert-vj-start:
	@./vj-background-start.sh convert-vj "make convert-vj-status" "$$HOME/.cache/yt-dlp/convert-vj.log" ./vj-run-limited.sh ./convert-vj

convert-vj-status:
	@./convert-vj-status

convert-vj-stop:
	@./convert-vj-stop

convert-vj-stop-next:
	@./convert-vj-stop-next

convert-vj-restart-next:
	@./vj-restart-next.sh convert-vj "make convert-vj-status" "$$HOME/.cache/yt-dlp/convert-vj.log" ./vj-run-limited.sh ./convert-vj

convert-vj-splits convert-vj-splits-start:
	@./convert-vj-splits-start

convert-vj-splits-status:
	@./convert-vj-splits-status

convert-vj-splits-stop:
	@./convert-vj-splits-stop

convert-vj-splits-stop-next:
	@./convert-vj-splits-stop-next

# make convert-vj-splits-20s → 20 second clips. The number before the final s is the length.
# Drop built-in suffix rules here so a typo is not compiled as assembler (.s).
.SUFFIXES:
# Explicit targets above (status, stop, start) win when they also match this pattern.
.PHONY: vj-splits-seconds-force
vj-splits-seconds-force:
	@:

convert-vj-splits-%s: vj-splits-seconds-force
	@sec='$*'; \
	case "$$sec" in \
	  ''|*[!0-9]*) echo "Clip length must be a whole number of seconds. Example: make convert-vj-splits-20s" >&2; exit 1 ;; \
	esac; \
	sec=$$((10#$$sec)); \
	if [ "$$sec" -lt 1 ] || [ "$$sec" -gt 86400 ]; then \
	  echo "Clip length must be from 1 to 86400 seconds (got $$sec)." >&2; exit 1; \
	fi; \
	VJ_SPLIT_SEGMENT_SEC="$$sec" ./convert-vj-splits-start
