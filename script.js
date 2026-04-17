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
    const modalContent = document.getElementById('modal-content-inner');
    const modalClose = document.querySelector('.modal-close'); 
    const openPrivacy = document.getElementById('open-privacy');
    const openLegal = document.getElementById('open-legal');

    if (modalOverlay && modalContent) {

        function openModal(type) {
            const sourceId = type === 'privacy' ? 'content-privacy' : 'content-legal';
            const source = document.getElementById(sourceId);
            if (source) {
                modalContent.innerHTML = source.innerHTML;
            }
            modalOverlay.classList.add('active');
            document.body.style.overflow = 'hidden'; 
        }

        function closeModal() {
            modalOverlay.classList.remove('active');
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

        // Burger Menu Logic
        const burger = document.querySelector('#burger-toggle');
        const menu = document.querySelector('#mobile-menu');
        const menuLinks = document.querySelectorAll('.mobile-links a');

        if (burger) {
            burger.addEventListener('click', () => {
                menu.classList.toggle('active');
                burger.classList.toggle('toggle');
            });
        }

        // Fermer le menu au clic sur un lien
        menuLinks.forEach(link => {
            link.addEventListener('click', () => {
                menu.classList.remove('active');
                burger.classList.remove('toggle');
            });
        });
        // Smooth Scroll pour tous les liens internes
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', function (e) {
                const href = this.getAttribute('href');
                if (href === '#') return;
                
                e.preventDefault();
                const target = document.querySelector(href);
                if (target) {
                    target.scrollIntoView({
                        behavior: 'smooth'
                    });
                }
            });
        });

        // Logo Click -> Retour en haut
        const logo = document.getElementById('main-logo');
        if (logo) {
            logo.addEventListener('click', (e) => {
                e.preventDefault();
                window.scrollTo({
                    top: 0,
                    behavior: 'smooth'
                });
            });
        // 7. Tracking des visites
        logVisit();
    }
});

// Fonction de tracking anonyme
async function logVisit() {
    const supabaseUrl = 'https://aswxkjibvcadnwujzwcm.supabase.co';
    const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzd3hramlidmNhZG53dWp6d2NtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNTE3MjMsImV4cCI6MjA5MTgyNzcyM30.DunVTxcbIm0ausnk_4pdnkyn58tdoZf5ioLKqtk5tro';
    
    try {
        const visitData = {
            page_path: window.location.pathname,
            referrer: document.referrer || 'direct',
            screen_resolution: `${window.screen.width}x${window.screen.height}`,
            user_agent: navigator.userAgent,
            device_type: /Mobi|Android/i.test(navigator.userAgent) ? 'mobile' : 'desktop',
            created_at: new Date().toISOString()
        };

        await fetch(`${supabaseUrl}/rest/v1/site_visits`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'apikey': supabaseKey,
                'Authorization': `Bearer ${supabaseKey}`
            },
            body: JSON.stringify(visitData)
        });

        // Setup Event Listeners after visit is logged
        setupEventListeners();
    } catch (err) {
        // Silencieux
    }
}

// Fonction de tracking d'événements (clics, etc.)
async function logEvent(name, data = {}) {
    const supabaseUrl = 'https://aswxkjibvcadnwujzwcm.supabase.co';
    const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzd3hramlidmNhZG53dWp6d2NtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNTE3MjMsImV4cCI6MjA5MTgyNzcyM30.DunVTxcbIm0ausnk_4pdnkyn58tdoZf5ioLKqtk5tro';
    
    try {
        await fetch(`${supabaseUrl}/rest/v1/site_events`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'apikey': supabaseKey,
                'Authorization': `Bearer ${supabaseKey}`
            },
            body: JSON.stringify({
                event_name: name,
                event_data: data,
                created_at: new Date().toISOString()
            })
        });
    } catch (err) { /* Silent */ }
}

function setupEventListeners() {
    // Boutons APK / WebApp
    document.querySelectorAll('a').forEach(link => {
        const text = link.innerText.toLowerCase();
        const href = link.getAttribute('href') || '';
        
        if (text.includes('apk') || href.includes('apk')) {
            link.addEventListener('click', () => logEvent('click_download_apk'));
        }
        if (text.includes('webapp') || text.includes('lancer') || text.includes('connecter')) {
            link.addEventListener('click', () => logEvent('click_launch_app'));
        }
    });

    // Interaction Simulateur - Plus de détails
    const addDrinkBtn = document.querySelector('.add-drink-btn');
    if (addDrinkBtn) {
        addDrinkBtn.addEventListener('click', () => {
            const drinkType = document.querySelector('.drink-type-select')?.textContent || 'vague';
            logEvent('simulator_add_drink', { type: drinkType });
        });
    }

    const ageInput = document.getElementById('age-input');
    if (ageInput) { ageInput.addEventListener('change', () => logEvent('simulator_param', { p: 'age' })); }

    const weightInput = document.getElementById('weight-input');
    if (weightInput) { weightInput.addEventListener('change', () => logEvent('simulator_param', { p: 'weight' })); }

    // HEARTBEAT : Détection de présence toutes les 30 secondes
    setInterval(() => {
        logEvent('heartbeat', { url: window.location.pathname });
    }, 30000);
}
