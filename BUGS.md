# Active Defects

- **BUG-LT-001 (Test Cleanup Interference):** Linked to LT-REQ-003. When RSpec tests are executed in the background or manually, `file_manager_spec.rb` blindly invokes `FileUtils.rm_rf("downloads")` in its `before` and `after` hooks. This deletes the legitimate `downloads` directory created by actual CLI usage if they are executed from the same root directory.

## Resolved Defects

*(No resolved defects)*
