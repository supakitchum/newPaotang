# Game Lottery Background Assets

Place game-scoped background assets here only when they are intentionally committed for local/dev or fixture use.

Production background uploads should normally go through the central background asset upload workflow and be stored in private S3-compatible object storage.

Expected game-scoped layout:

```text
{game_id}/backgrounds/{version}/odd
{game_id}/backgrounds/{version}/even
{game_id}/backgrounds/{version}/charity
```

Example:

```text
gam_20260601/backgrounds/v1/odd/001.webp
gam_20260601/backgrounds/v1/odd/002.webp
gam_20260601/backgrounds/v1/even/001.webp
gam_20260601/backgrounds/v1/charity/001.webp
```

Background sets may arrive at different times. `odd` can be ready first and allow early sale, while `even` and `charity` rows remain pending until their assets are ready.

Do not place generated lottery ticket images in this directory.
