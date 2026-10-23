.PHONY: youtube-vj youtube-vj-start youtube-vj-status youtube-vj-stop youtube-vj-stop-next youtube-vj-restart-next \
        convert-vj convert-vj-start convert-vj-status convert-vj-stop convert-vj-stop-next convert-vj-restart-next

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
