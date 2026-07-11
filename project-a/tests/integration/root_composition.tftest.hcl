run "root_shell_stays_in_default_workspace" {
  command = plan

  assert {
    condition     = terraform.workspace == "default"
    error_message = "The root composition shell must stay in the default workspace."
  }
}

run "environment_docs_remain_present" {
  command = plan

  assert {
    condition     = terraform.workspace == "default" && fileexists("${path.root}/environments/README.md")
    error_message = "Environment composition guidance must remain present."
  }
}
