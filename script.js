// Animations et interactions au survol
document.addEventListener('DOMContentLoaded', () => {
    // 1. Détection de scroll pour révéler les éléments en douceur (Lazy reveal)
    const cards = document.querySelectorAll('.feature-card');
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
                entry.target.style.filter = 'blur(0px)';
                // Une fois révélé, on retire la transition de délai pour ne pas gêner le tilt
                setTimeout(() => {
                    entry.target.style.transition = 'transform 0.3s cubic-bezier(0.23, 1, 0.32, 1), opacity 0.8s ease, filter 1s ease';
                }, 1500);
            }
        });
    }, { 
        threshold: 0.1,
        rootMargin: "0px 0px -50px 0px"
    });

    cards.forEach((card, index) => {
        card.style.opacity = '0';
        card.style.transform = 'translateY(40px)';
        card.style.filter = 'blur(10px)';
        card.style.transition = `all 0.8s cubic-bezier(0.175, 0.885, 0.32, 1.275) ${index * 0.15}s, filter 1s ease ${index * 0.15}s`;
        observer.observe(card);
    });

    // 1.b Détection du graphique pour lancer l'animation de tracé
    const graphSection = document.querySelector('.analysis-visual');
    if (graphSection) {
        const graphObserver = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('animate-graph');
                }
            });
        }, { threshold: 0.3 });
        graphObserver.observe(graphSection);
    }

    // 2. Logique du Carrousel des Screenshots
    const track = document.querySelector('.carousel-track');
    const prevBtn = document.querySelector('.prev-btn');
    const nextBtn = document.querySelector('.next-btn');

    if (track && prevBtn && nextBtn) {
        prevBtn.addEventListener('click', () => {
            const slideWidth = track.querySelector('.carousel-slide').offsetWidth + 30; // 30 = gap
            track.scrollBy({ left: -slideWidth, behavior: 'smooth' });
        });

        nextBtn.addEventListener('click', () => {
            const slideWidth = track.querySelector('.carousel-slide').offsetWidth + 30;
            track.scrollBy({ left: slideWidth, behavior: 'smooth' });
        });
    }

    // 3. Gestion des Modales Légales
    const modalOverlay = document.getElementById('modal-overlay');
    const modalContent = document.getElementById('modal-content');
    const modalClose = document.querySelector('.modal-close');
    const openPrivacy = document.getElementById('open-privacy');
    const openLegal = document.getElementById('open-legal');

    if (modalOverlay && modalContent) {
        const legalData = {
            privacy: `
                <h2>Politique de confidentialité</h2>
                <p><i>Dernière mise à jour : 15 Avril 2026</i></p>
                <h3>1. Présentation</h3>
                <p>Journal Conso est une application mobile permettant à l’utilisateur de tenir un journal personnel de consommation d’alcool, de consulter des statistiques indicatives et de gérer ses données localement sur son appareil.</p>
                <h3>2. Données enregistrées</h3>
                <p>L’application enregistre localement vos consommations, vos profils, vos préférences et vos statistiques.</p>
                <h3>3. Stockage local uniquement</h3>
                <p><strong>Toutes les données de Journal Conso sont stockées uniquement sur votre appareil.</strong> L’application n’envoie aucune donnée à son auteur, à un serveur distant ou à des tiers.</p>
                <h3>4. Absence de compte et de suivi</h3>
                <p>L’application fonctionne sans compte utilisateur, sans publicité et sans aucun traqueur externe.</p>
                <h3>5. Limites</h3>
                <p>Journal Conso n'est pas un dispositif médical. Les estimations d'alcoolémie sont indicatives. L'application ne doit jamais déterminer une aptitude à conduire.</p>
                <h3>6. Contact</h3>
                <p>Auteur : ChrisK<br>Contact : journalconso@gmail.com</p>
            `,
            legal: `
                <h2>Mentions légales</h2>
                <p>Journal Conso est une application de suivi personnel permettant d’enregistrer localement sa consommation d’alcool et d’afficher des statistiques indicatives.</p>
                <h3>Confidentialité</h3>
                <p>Vos données sont stockées uniquement sur votre appareil (Stockage local / Shared Preferences). L’application ne transmet aucune donnée à des tiers.</p>
                <h3>Avertissement important</h3>
                <p>Journal Conso n’est pas un dispositif médical. Les estimations affichées sont indicatives et ne remplacent ni un éthylotest, ni un avis médical, ni les règles légales applicables (Code de la route).</p>
                <p>L'utilisation de cette application se fait sous la seule responsabilité de l'utilisateur.</p>
                <h3>Auteur & Contact</h3>
                <p>ChrisK<br>journalconso@gmail.com</p>
            `
        };

        function openModal(type) {
            modalContent.innerHTML = legalData[type];
            modalOverlay.style.display = 'flex';
            document.body.style.overflow = 'hidden'; 
        }

        function closeModal() {
            modalOverlay.style.display = 'none';
            document.body.style.overflow = 'auto';
        }

        if (openPrivacy) openPrivacy.onclick = (e) => { e.preventDefault(); openModal('privacy'); };
        if (openLegal) openLegal.onclick = (e) => { e.preventDefault(); openModal('legal'); };
        if (modalClose) modalClose.onclick = closeModal;
        modalOverlay.onclick = (e) => { if(e.target === modalOverlay) closeModal(); };
    }

    // 4. Simulateur Interactif d'Alcoolémie (Logic)
    const drinkPlus = document.getElementById('drink-plus');
    const drinkMinus = document.getElementById('drink-minus');
    const simUnitsVal = document.getElementById('sim-units-val');
    const simVal = document.getElementById('sim-val');
    const simCircle = document.getElementById('sim-circle');
    const simStatusText = document.getElementById('sim-status-text');
    const simStatusIcon = document.getElementById('sim-status-icon');

    let units = 0;

    function updateSimulator() {
        const bac = units * 0.18; 
        simVal.textContent = bac.toFixed(2);
        simUnitsVal.textContent = units;

        if (bac === 0) {
            simCircle.style.borderColor = 'rgba(255,255,255,0.05)';
            simCircle.style.borderTopColor = 'var(--accent)';
            simCircle.style.borderRightColor = 'var(--accent)';
            simStatusText.textContent = "Sécurité OK";
            simStatusText.style.color = "#4CAF50";
            simStatusIcon.textContent = "✓";
            simStatusIcon.style.color = "#4CAF50";
        } else if (bac < 0.5) {
            simCircle.style.borderColor = "#4CAF50";
            simStatusText.textContent = "Léger - Vigilance";
            simStatusText.style.color = "#4CAF50";
            simStatusIcon.textContent = "✓";
            simStatusIcon.style.color = "#4CAF50";
        } else if (bac < 0.8) {
            simCircle.style.borderColor = "#FFC107";
            simStatusText.textContent = "Limite atteinte";
            simStatusText.style.color = "#FFC107";
            simStatusIcon.textContent = "⚠";
            simStatusIcon.style.color = "#FFC107";
        } else {
            simCircle.style.borderColor = "#F44336";
            simStatusText.textContent = "Danger - Fixe";
            simStatusText.style.color = "#F44336";
            simStatusIcon.textContent = "✕";
            simStatusIcon.style.color = "#F44336";
        }
    }

    if (drinkPlus) drinkPlus.addEventListener('click', () => { units++; updateSimulator(); });
    if (drinkMinus) drinkMinus.addEventListener('click', () => { if (units > 0) units--; updateSimulator(); });

    // 5. Effet Parallaxe 3D (Tilt) Premium
    const tiltElements = document.querySelectorAll('[data-tilt]');

    tiltElements.forEach(el => {
        el.addEventListener('mousemove', (e) => {
            requestAnimationFrame(() => {
                const rect = el.getBoundingClientRect();
                const x = e.clientX - rect.left;
                const y = e.clientY - rect.top;
                
                const centerX = rect.width / 2;
                const centerY = rect.height / 2;
                
                const rotateX = (y - centerY) / 25; // Moins sensible
                const rotateY = (centerX - x) / 25;
                
                el.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale3d(1.02, 1.02, 1.02)`;
            });
        });

        el.addEventListener('mouseleave', () => {
            requestAnimationFrame(() => {
                el.style.transform = `perspective(1000px) rotateX(0deg) rotateY(0deg) scale3d(1, 1, 1)`;
            });
        });
    });
    
    // 6. Gestion du Formulaire de Contact via Supabase
    const contactForm = document.getElementById('contact-form');
    const contactSuccess = document.getElementById('contact-success');
    const submitBtn = document.getElementById('btn-submit-contact');

    if (contactForm && contactSuccess) {
        contactForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            
            // État de chargement
            submitBtn.disabled = true;
            submitBtn.textContent = "Envoi en cours...";
            
            const formData = {
                name: document.getElementById('contact-name').value,
                email: document.getElementById('contact-email').value,
                subject: document.getElementById('contact-subject').value,
                message: document.getElementById('contact-message').value,
                created_at: new Date().toISOString()
            };

            // 1. Sauvegarde dans Supabase (La sécurité)
            const supabasePromise = fetch('https://aswxkjibvcadnwujzwcm.supabase.co/rest/v1/contact_messages', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzd3hramlidmNhZG53dWp6d2NtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNTE3MjMsImV4cCI6MjA5MTgyNzcyM30.DunVTxcbIm0ausnk_4pdnkyn58tdoZf5ioLKqtk5tro',
                    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzd3hramlidmNhZG53dWp6d2NtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNTE3MjMsImV4cCI6MjA5MTgyNzcyM30.DunVTxcbIm0ausnk_4pdnkyn58tdoZf5ioLKqtk5tro'
                },
                body: JSON.stringify({
                    name: document.getElementById('contact-name').value,
                    email: document.getElementById('contact-email').value,
                    subject: document.getElementById('contact-subject').value,
                    message: document.getElementById('contact-message').value
                })
            });

            // 2. Envoi de l'Email (La notification)
            const emailForm = new FormData();
            emailForm.append("Nom", document.getElementById('contact-name').value);
            emailForm.append("Email", document.getElementById('contact-email').value);
            emailForm.append("Sujet", document.getElementById('contact-subject').value);
            emailForm.append("Message", document.getElementById('contact-message').value);
            emailForm.append("_subject", "🚀 Nouveau message JOURNAL CONSO");
            emailForm.append("_captcha", "false"); // On désactive le captcha pour plus de fluidité

            const emailPromise = fetch('https://formsubmit.co/ajax/journalconso@gmail.com', {
                method: 'POST',
                headers: {
                    'Accept': 'application/json'
                },
                body: emailForm
            });

            try {
                // On attend que les deux soient lancés
                const [supaRes, emailRes] = await Promise.all([supabasePromise, emailPromise]);

                if (supaRes.ok || emailRes.ok) {
                    contactForm.style.display = 'none';
                    contactSuccess.style.display = 'block';
                    contactSuccess.style.animation = 'fadeIn 0.5s ease forwards';
                } else {
                    throw new Error('Erreur de transmission');
                }
            } catch (error) {
                console.error('Erreur:', error);
                alert("Oups, une erreur est survenue lors de l'envoi. Veuillez réessayer.");
                submitBtn.disabled = false;
                submitBtn.textContent = "Envoyer le message";
            }
        });
    }
});
