function toggleAnswer(element) {
    const parent = element.parentElement;
    const answer = parent.querySelector('.faq-answer');
    const icon = element.querySelector('.icon');

    // Toggle kelas untuk mengontrol animasi
    if (parent.classList.contains('open')) {
        parent.classList.remove('open');
        icon.textContent = "▼";
    } else {
        parent.classList.add('open');
        icon.textContent = "▲";
    }
}
