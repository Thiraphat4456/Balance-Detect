# External implementation review

Reviewed on 2026-08-27:

- Repository: <https://github.com/SupakornMuattia/2301487-Senior-Project>
- Reviewed head: `061fc540e0375bd9253e2ffae0e0c6fe0e4531ef`
- License status at review time: no repository-level `LICENSE` file was present.

No source code, model binary, Android platform tool, or other artifact from that
repository was copied into Balance Detect. The review was used as prior art to
identify ideas that could be independently implemented and tested in Dart.

## Adopted independently

- Validate the Functional Reach starting posture from pose joint angles. Balance
  Detect now waits for approximately 90 degrees at the shoulder and an extended
  elbow before accepting the baseline or starting the hands-free countdown.
- Lock the selected reaching side when the first valid baseline frame arrives,
  then use that same wrist through baseline and active measurement. This avoids
  mixing left/right wrists when landmark confidence alternates between frames.
- Keep temporal noise handling close to the measurement that consumes it. The
  existing Balance Detect wrist/foot windows, planted-foot anchors, adaptive
  noise floor, and multi-frame confirmation remain in place instead of adding a
  second whole-pose smoothing layer.

The 90-degree starting posture and extended arm follow published Functional
Reach procedures, including:

- Duncan et al., *Functional reach: a new clinical measure of balance*:
  <https://pubmed.ncbi.nlm.nih.gov/2229941/>
- Mobile Functional Reach Test protocol description:
  <https://pmc.ncbi.nlm.nih.gov/articles/PMC5454544/>

The 75-105 degree shoulder tolerance and 150-degree elbow threshold are
prototype computer-vision tolerances, not clinical cutoffs. They require
validation with labeled recordings and real participants.

## Not adopted

- Python/OpenCV IP-camera pipeline: it is a desktop prototype and duplicates the
  existing native Flutter CameraX + ML Kit path.
- ADB-based focal-length calibration: an installed mobile app cannot depend on a
  desktop `adb.exe`, and the hard-coded local path is device/developer specific.
- Average-IPD distance estimation: it needs a face/iris model, camera intrinsics,
  crop-aware calibration, and participant-level error validation before it can
  safely guide measurement.
- Bundled MediaPipe models and Android platform-tool binaries: they add large
  duplicated artifacts and have separate provenance/license requirements.
- Footstep detection from absolute ankle-to-ankle distance over 10 cm: ordinary
  stance width can exceed that threshold, so it does not prove that either foot
  moved from its own baseline.
- Knee and trunk-compensation checks: missing landmarks currently pass some of
  those checks in the reviewed prototype, while trunk rotation detection is not
  active. They need a defined protocol and labeled validation before use.
