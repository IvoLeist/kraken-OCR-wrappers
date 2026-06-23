# Segmentation diff

<div class="segmentation-diff-toolbar">
  <button
    type="button"
    class="md-button"
    onclick="toggleSegmentationDiffFullscreen()"
  >
    Full screen
  </button>
</div>

<iframe
  id="segmentation-diff-frame"
  class="segmentation-diff-frame"
  src="../segmentation-diff.html"
  title="Kraken segmentation diff"
  allowfullscreen
  allow="fullscreen"
></iframe>

<p class="segmentation-diff-note">
  If the frame is empty, rebuild the site with <code>make pages-build</code> so the latest diff HTML is generated.
</p>

<script>
function toggleSegmentationDiffFullscreen() {
    const frame = document.getElementById("segmentation-diff-frame");

    if (!document.fullscreenElement) {
        frame.requestFullscreen();
    } else {
        document.exitFullscreen();
    }
}
</script>