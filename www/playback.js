// Advance only after the requested plot image has loaded. A free-running clock
// can queue years faster than R draws them, causing mismatched maps and sliders.
(function () {
  let playing = false;
  let timer = null;
  let pendingYear = null;
  function cancelStep() {
    if (timer !== null) clearTimeout(timer);
    timer = null;
  }
  function readyForCurrentYear() {
    const map = document.getElementById('map');
    const image = map && map.querySelector('img');
    const slider = $('#year').data('ionRangeSlider');
    const match = image && image.alt.match(/\| Year: (\d+)$/);
    return !!(pendingYear === null && map && !map.classList.contains('recalculating') && image &&
      image.complete && image.naturalWidth > 0 && slider && match &&
      Number(match[1]) === slider.result.from);
  }
  function scheduleStep() {
    cancelStep();
    if (!playing || !readyForCurrentYear()) return;
    const seconds = Number($('#speed').val());
    if (!Number.isFinite(seconds) || seconds < .1 || seconds > 1.5) return;
    timer = setTimeout(function () {
      timer = null;
      if (!playing || !readyForCurrentYear()) return;
      const slider = $('#year').data('ionRangeSlider');
      const next = slider.result.from >= slider.result.max ? slider.result.min : slider.result.from + 1;
      pendingYear = next;
      Shiny.setInputValue('viewer_frame_year', next, {priority:'event'});
      // No new timer until the new year's image is displayed.
    }, seconds * 1000);
  }
  function frameAvailable() {
    const image = document.querySelector('#map img');
    const match = image && image.alt.match(/\| Year: (\d+)$/);
    if (pendingYear !== null && image && image.complete && image.naturalWidth > 0 &&
        match && Number(match[1]) === pendingYear) {
      const displayedYear = pendingYear;
      pendingYear = null;
      $('#year').data('ionRangeSlider').update({from:displayedYear});
      $('#year').trigger('change');
    }
    scheduleStep();
  }
  function setPlaying(value) {
    playing = value;
    const button = document.getElementById('play_animation');
    if (button) {
      button.innerHTML = playing ? '<i class="fa fa-pause" aria-hidden="true"></i> Pause animation' :
        '<i class="fa fa-play" aria-hidden="true"></i> Play animation';
      button.setAttribute('aria-pressed', String(playing));
    }
    scheduleStep();
  }
  $(document).on('click', '#play_animation', function () { setPlaying(!playing); });
  $(document).on('shiny:connected', function () { setPlaying(false); });
  $(document).on('shiny:disconnected', function () { setPlaying(false); });
  $(document).on('shiny:recalculating', function (event) {
    if (event.target.id === 'map') cancelStep();
  });
  $(document).on('shiny:inputchanged', function (event) {
    if (['program','name_mode','species','viewport','policy'].includes(event.name)) {
      pendingYear = null;
      setPlaying(false);
    }
    else if (event.name === 'year' && pendingYear !== null) {
      pendingYear = null;
      setPlaying(false);
    } else if (event.name === 'year' || event.name === 'speed') scheduleStep();
  });
  // Native load does not bubble; capture it after Shiny updates the plot image.
  document.addEventListener('load', function (event) {
    if (event.target.tagName === 'IMG' && event.target.closest('#map')) frameAvailable();
  }, true);
  $(document).on('shiny:value', function (event) {
    if (event.name === 'map') requestAnimationFrame(frameAvailable);
  });
  $(document).on('shiny:recalculated', function (event) {
    if (event.target.id === 'map') frameAvailable();
  });
})();
