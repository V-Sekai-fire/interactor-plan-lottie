import Lake
open Lake DSL

package «plan-lottie»

lean_lib PlanLottie

@[default_target]
lean_exe plan_lottie where
  root := `Main

lean_exe plan_lottie_witness where
  root := `Witness

lean_exe yamlld_witness where
  root := `YamlLdWitness
