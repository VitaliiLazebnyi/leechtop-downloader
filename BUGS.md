# Active Defects

None.

## Resolved Defects

- **BUG-LT-001 (Test Cleanup Interference):** Linked to LT-REQ-003. When RSpec tests are executed in the background or
  manually, `file_manager_spec.rb` blindly invokes `FileUtils.rm_rf("downloads")` in its `before` and `after` hooks.
  This deletes the legitimate `downloads` directory created by actual CLI usage if they are executed from the same
  root directory.
- **BUG-LT-002 (Path Traversal in File Names):** Linked to LT-REQ-003. The file name comes from the network (the page
  title, or the `Content-Disposition` header of the download) and was joined to the destination directory unchanged:
  a name such as `../../.bashrc` was written outside the destination, and a page title containing a slash
  (`Vol 1/2.zip`) aborted the run with `Errno::ENOENT`. Path separators and NUL bytes are now replaced with `_`.
- **BUG-LT-003 (One Failing Page Aborted the Batch):** Linked to LT-REQ-002. A page that answered with an HTTP error, or
  a server that could not be reached, raised a `RuntimeError` (or a `Faraday::Error`) that the CLI did not rescue: the
  run stopped with a stack trace and the remaining URLs were never downloaded. Such failures are now reported
  (`Error downloading ...` / `Error fetching links from ...`) and the run continues with the next URL.
- **BUG-LT-004 (Loose leechtop.com URL Check):** Linked to LT-REQ-002. The leechtop.com URL pattern was anchored with
  `^` (start of any line) instead of `\A` (start of the string), so a link whose text contained a newline followed by
  a leechtop.com URL was taken for a leechtop.com link.
- **BUG-LT-005 (Binary Chunk Size):** Linked to LT-REQ-004. Streams were copied in chunks of 8192 bytes, which is
  8 KiB (binary), not 8 kB. The chunk size is now 8000 bytes.
- **BUG-LT-006 (Ruby Warnings from the Executable):** `exe/leechtop` assigned `Encoding.default_external` and
  `Encoding.default_internal` at runtime, which Ruby reports as a warning. The only input it affected, the text file of
  links, is now read as UTF-8 explicitly.
