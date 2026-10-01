    42	- `reward-publish-spike.js`
    43	- `reward-checking-queue-chunk.js`
    44	- `ticket-image-cdn-spike.js`
    45	
    46	The first six scenarios run against local/dev API fixtures. `ticket-image-cdn-spike.js` remains a runnable CDN/object-storage template; the baseline runner records a skipped artifact unless `CDN_BASE_URL` and `IMAGE_PATH` are supplied for a real Cloudflare/CDN/R2 ticket image path.
    47	
    48	`ticket-image-cdn-spike.js` intentionally ignores normal API `BASE_URL`. CDN/R2 coverage is only claimable with explicit `CDN_BASE_URL` and `IMAGE_PATH`.
