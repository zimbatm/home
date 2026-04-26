# ops: rotate and set NVIDIA NIM API key

## what

Rotate the NVIDIA NIM key that was pasted into chat, then store the new value in kin as an external secret for the planned `llm-nvidia-adapter`.

Do **not** commit the key to git or paste it into backlog.

## why

`backlog/adopt-nvidia-nim-llm-adapter.md` needs an API key for `https://integrate.api.nvidia.com/v1`, but the key must not live in the repository or Nix store. The previously pasted key should be treated as compromised.

## human steps

1. Revoke/rotate the key in NVIDIA Build/NIM dashboard.
2. Set the rotated value via kin secret input:

   ```sh
   kin set llm-nvidia/api-key/_shared/key
   ```

   Paste the new key at the prompt.

3. Run safe checks only:

   ```sh
   kin gen --check
   ```

4. Do not deploy from this item; deploy remains human-gated separately.

## close when

- The leaked key has been revoked.
- A new key is stored through `kin set` after the adapter gen target exists.
- No plaintext API key appears in git history, backlog, generated public files, or Nix store references.
