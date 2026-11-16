# presence_edit

## Then 0. Run usd guest to Run seethrough guest

1 when the guest ELF of that name has run its stage: usd, udim_unpack, remesh, cage, drape, cloth_fit, garment_fit,
headfit, skintokens, skintokens_rig, pixal3d, seethrough.

1. Run usd guest. not timed. Sets usd.
2. Run udim unpack guest. not timed. Sets udim_unpack.
3. Run remesh guest. not timed. Sets remesh.
4. Run cage guest. not timed. Sets cage.
5. Run drape guest. not timed. Sets drape.
6. Run cloth fit guest. not timed · GPU. Sets cloth_fit, GPU.
7. Run garment fit guest. not timed. Sets garment_fit.
8. Run headfit guest. not timed. Sets headfit.
9. Run skintokens guest. not timed · GPU. Reads GPU from Run cloth fit guest. Sets skintokens, GPU.
10. Run skintokens rig guest. not timed · GPU. Reads GPU from Run skintokens guest. Sets skintokens_rig, GPU.
11. Run pixal3d guest. not timed · GPU. Reads GPU from Run skintokens rig guest. Sets pixal3d, GPU.
12. Run seethrough guest. not timed · GPU. Reads GPU from Run pixal3d guest. Sets seethrough, GPU.

