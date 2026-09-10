# Contract Python-to-shell regression coverage

The original 36 Python unittest methods map to the following shell cases; several related assertions share a case. Shell cases run in independent Bash subprocesses with errexit, so a failed intermediate assertion cannot be hidden by a later success.

| Original method (test_ prefix omitted) | tests/test-contract.sh case |
|---|---|
| valid_committed_test_passes | test_valid_gate |
| pending_entry_rejected_for_completion | test_pending |
| current_plan_cannot_weaken_approved_body | test_weakened_plan |
| pending_entry_cannot_be_deleted | test_deleted_plan |
| declared_format_and_lint_fail_without_git_hooks | test_hygiene_hooks_disabled (both Format/Lint) |
| hygiene_success_output_is_allowed_and_both_checks_run | test_hygiene_output_mutation (both commands/output) |
| hygiene_source_mutation_is_rejected | test_hygiene_output_mutation |
| gofmt_listing_is_failure_even_with_zero_exit | test_gofmt |
| spec_and_runner_commands_are_frozen | test_frozen_spec_commands (both) |
| checkbox_like_text_inside_code_is_frozen | test_frozen_header_checkbox |
| header_shared_constant_cannot_change | test_changed_header |
| missing_and_invalid_baseline_fail_closed | test_invalid_baseline_missing_plan (both) |
| dirty_worktree_cannot_mask_broken_head | test_dirty_head |
| index_and_untracked_inputs_are_rejected | test_index_untracked (both) |
| negative_and_binary_fixture_changes_rejected | test_negative_binary_fixtures (both) |
| test_rename_is_rejected | test_rename |
| commented_test_is_not_execution_evidence | test_commented |
| skipped_approved_test_is_not_passing_evidence | test_skipped |
| unverifiable_success_command_rejected | test_unsupported_runner |
| appended_defect_is_pending_and_never_implicitly_approved | test_appended_unapproved |
| explicit_node_target_need_not_match_filename_globs | test_explicit_target |
| npm_test_uses_real_tap_and_script_is_frozen | test_npm_frozen_script |
| real_assertion_failure_is_red_with_named_evidence | test_real_red_build_error |
| syntax_error_is_infrastructure_not_behavioral_red | test_real_red_build_error (rc11 vs rc10) |
| suite_sigint_terminates_its_separate_process_group | test_suite_cancellation |
| runner_timeout_is_not_red | test_timeout |
| runner_side_effect_cannot_leave_gate_green | test_side_effect |
| checked_entry_cannot_be_unchecked | test_uncheck_complete |
| missing_baseline_does_not_default_to_head | test_saved_baseline |
| legacy_loop_file_is_not_explicit_approval | test_saved_baseline |
| corrupt_state_does_not_fall_back_to_legacy | test_saved_baseline |
| linked_worktree_and_state_baseline_supported | test_worktree |
| go_actual_pass_fail_and_compile_error_are_distinct | test_go_evidence (actual Go) |
| real_vitest_pass_failure_and_skip_evidence | test_vitest_evidence (actual locally installed Vitest) |
| rejects_empty_duplicate_unclosed_and_missing_blocks | test_plan_malformed (also uppercase checkbox) |
| go_entry_fields | test_go_plan_exact |

Additional cases/assertions include exact Node code/header/heading/target, quoted gofmt, Go import-only additions vs changed tests, normal child rc7/timeout124/cancellation130, live-orphan refusal via kill builtin, and skip-worktree/assume-unchanged flags hiding broken HEAD.

Run the maintained aggregate with `bash tests/run.sh`. Set
`SOBAYA_TEST_VITEST_ROOT` to an existing app installation to include real Vitest.
The suite uses temporary repositories and deterministic shell workers.
