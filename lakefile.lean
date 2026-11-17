import Lake
open Lake DSL

package «plan-lottie»

require «lean-yaml-ld» from git "https://github.com/V-Sekai-fire/lean-yaml-ld" @ "9b24c877f873748dc63ba25fd5cc63772ba7ff32"

lean_lib PlanLottie

@[default_target]
lean_exe plan_lottie where
  root := `Main

lean_exe plan_lottie_witness where
  root := `Witness
