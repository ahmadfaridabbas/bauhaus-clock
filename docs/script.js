const image = document.querySelector('#style-image');
const nameLabel = document.querySelector('#style-name');
for (const button of document.querySelectorAll('[data-style]')) {
  button.addEventListener('click', () => {
    const name = button.querySelector('strong').textContent;
    image.src = `assets/style-${button.dataset.style}.jpg`;
    image.alt = `${name} hands on the Original dark dial`;
    nameLabel.textContent = name;
    for (const item of document.querySelectorAll('[data-style]')) {
      item.setAttribute('aria-pressed', String(item === button));
    }
    if (window.matchMedia('(max-width: 680px)').matches) {
      document.querySelector('.style-preview').scrollIntoView({
        behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth',
        block: 'start'
      });
    }
  });
}
const dialog = document.querySelector('#image-dialog');
const largeImage = document.querySelector('#large-image');
for (const link of document.querySelectorAll('.shot')) {
  link.addEventListener('click', event => {
    if (typeof dialog.showModal !== 'function' || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    largeImage.src = link.href;
    largeImage.alt = link.querySelector('img').alt;
    document.querySelector('#image-caption').textContent = link.dataset.caption;
    dialog.showModal();
  });
}
document.querySelector('#close-dialog').addEventListener('click', () => dialog.close());
dialog.addEventListener('click', event => { if (event.target === dialog) { const r = dialog.getBoundingClientRect(); if (event.clientX < r.left || event.clientX > r.right || event.clientY < r.top || event.clientY > r.bottom) dialog.close(); } });
