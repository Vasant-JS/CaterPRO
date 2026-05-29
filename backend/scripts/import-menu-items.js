const fs = require('fs');
const path = require('path');

const dbPath = path.join(__dirname, '..', 'db.json');
const db = JSON.parse(fs.readFileSync(dbPath, 'utf8'));

const rawItems = `
ಅಕ್ಕಿ ಕಡಲೆಬೇಳೆ ಪಾಯಸ/Akki kadalebele payasa
ಅಕ್ಕಿ ರೊಟ್ಟಿ/Akki rotti
ಆಲೂ ಬೋಂಡಾ/Aloo bonda
ಅಂಬೋಡೆ/Ambode
ಅನಾನಸ್ ಗೊಜ್ಜು/Ananas gojju
ಅಂಗೂರ್ ರಾಸ್ಮಲೈ/Angur rasmalai
ಅನ್ನ/Anna
ಅಪ್ಪೆ ಪಾಯಸ/Appe payasa
ಅಪ್ಪೆ ಸಾರು/Appe saaru
ಅವರೆಕಾಳು ಚಿತ್ರಾನ್ನ/Avarekalu chitranna
ಬೇಬಿಕಾರ್ನ್ ಮಂಚೂರಿ/Babycorn manchuri
ಬೇಬಿಕಾರ್ನ್ ಮಂಚೂರಿಯನ್/Babycorn manchurian
ಬಾದಾಮ್ ಹಾಲು/Badam milk
ಬಾದಮ್ ಪುರಿ/Badam puri
ಬಾದಾಮಿ ಬರ್ಫಿ/Badami burfi
ಬಾದಾಮಿ ಹಾಲು/Badami haalu
ಬಾದಾಮಿ ಹಲ್ವ ಕಪ್ಪಲ್ಲಿ/Badami Halwa in Cup
ಬದನೆ ಪಲ್ಯ/Badane palya
ಬಾದುಷಾ/Badusha
ಬಾಲಕ ಮೆಣಸಿನಕಾಯಿ/Balaka menasinakayi
ಬಾಳೆಹಣ್ಣು/Balehannu
ಬಳೆಕಾಯಿ ಫ್ರೈ/Balekayi fry
ಬಣ್ಣದ ಸೌತೆ ಸೊಪ್ಪು ನುಗ್ಗೆಕಾಯಿ ಸಾಂಬಾರ್/Bannada southe soppu nuggekayi sambar
ಬೀನ್ಸ್ ಕಾಳು ಪಲ್ಯ/Beans kalu palya
ಬೀನ್ಸ್ ಪಲ್ಯ/Beans palya
ಬೀಡಾ/Beeda
ಬೇಳೆ ಹೋಳಿಗೆ/Bele holige
ಬೆಂಡೆಕಾಯಿ ಫ್ರೈ/Bendekayi fry
ಬೆಂಡೆಕಾಯಿ ಸಾಸಿವೆ/Bendekayi sasive
ಬೆನ್ನೆ/Benne
ಬಿಳಿ ಹೋಳಿಗೆ/Bili holige
ಬಿಸಿಬೇಳೆಬಾತ್/Bisibelebath
ಬೊಂಬಾಯಿ ಬೋಂಡಾ/Bombayi bonda
ಬಟರ್‌ಸ್ಕಾಚ್ ಐಸ್‌ಕ್ರೀಮ್/Butterscotch icecream
ಕ್ಯಾರೆಟ್ ಹಲ್ವಾ/Carrot halwa
ಚಕ್ಕಲಿ ಮಸಾಲಾ/Chakkali masala
ಚಂಪಕಾಲಿ/Champakali
ಚನ್ನ ಬಟೂರಾ/Channa batura
ಚಪಾತಿ/Chapathi
ಚಟ್ನಿ/Chatni
ಚಿಪ್ಸ್/Chips
ಚಿರೋಟಿ/Chiroti
ಚಿತ್ರಾನ್ನ/Chitranna
ಚಾಕೊಲೇಟ್ ಬರ್ಫಿ/Chocolate burfi
ಚಟ್ನಿ/Chutney
ಕಾಫಿ/Coffee
ಕಾಂಗ್ರೆಸ್ ಕೋಸಂಬರಿ/Congress kosambari
ಜೋಳ ಕೋಸಂಬರಿ/Corn kosambari
ಜೋಳ ಪೇರಳೆ ಕೋಸಂಬರಿ/Corn perale kosambari
ಮೊಸರು/Curd
ಕರ್ಡ್ ರೈಸ್/Curd rice
ಹಣ್ಣು ಕಟ್/Cut fruits
ದಾಲಿಂಬೆ ಕೋಸಂಬರಿ/Dalimbe kosambari
ದಪ್ಪ ಮೆಣಸು ಬದನೆಕಾಯಿ ಪಲ್ಯ/Dappa menasu badanekayi palya
ಒಣ ಜಾಮೂನ್/Dry jamun
ಕುಂಬಳ ಕಾಯಿ ಹಲ್ವ/Dumroot
ಎಲೆಯಡಿಕೆ/Eleadike
ಎಣ್ಣೆಗಾಯಿ/Ennegayi
ಎಣ್ಣೆಗಾಯಿ ಪಲ್ಯ/Ennegayi palya
ಫ್ರೈಡ್ ರೈಸ್/Fried rice
ಫ್ರೂಟ್ ಪಂಚ್/Fruit punch
ಗಸಗಸೆ ಪಾಯಸ/Gasagase payasa
ಘೀ ರೈಸ್/Ghee rice
ಗೋಬಿ ಮಂಚೂರಿ/Gobi manchuri
ಗೋಧಿ ಹಲ್ವ/Godi Halwa
ಗೋದಿ ಕಡಿ ಪಾಯಸ/Godi kadi payasa
ಗೋಡಿ ಪಾಯಸ/Godi payasa
ಗೊಜ್ಜು/Gojju
ಗ್ರೀನ್ ಪೀಸ್ ಮಸಾಲಾ/Green peas masala
ಹಲಸಿನ ಹಪ್ಪಳ/Halisina Happala
ಹಲುಬಾಯಿ/Halubayi
ಹಲ್ವ/Halwa
ಹಪ್ಪಳ/Happala
ಹಯಗ್ರೀವ/Hayagreeva
ಹೀರೇಕಾಯಿ ಎಣ್ಣೆಗಾಯಿ/Heerekayi ennegayi
ಹೆಸರುಬೇಳೆ ಕೋಸಂಬರಿ/Hesarubele kosambari
ಹೆಸರುಕಾಳು/Hesarukalu
ಹೋಳಿಗೆ/Holige
ಹೋಳಿಗೆ ಸೀಕರನೇ/Holige seekarane
ಹುಳಿ/Huli
ಐಸ್ಕ್ರೀಮ್/Icecream
ಇಡ್ಲಿ/Idli
ಹಲಸಿನ ಹಣ್ಣಿನ ಪಾಯಸ/Jackfruit Payasa
ಜಹಾಂಗೀರ್/Jahangir
ಜಾಮೂನ್/Jamoon
ಜಿಲೇಬಿ/Jilebi
ಜೋಳದ ರೊಟ್ಟಿ/Jolada rotti
ಕಾಬೂಲ್ ಕಡಲೆ ಉಶ್ಲಿ/Kabul kadale ushli
ಕಡಲೆಬೇಳೆ ಹಯಗ್ರೀವ/Kadalebele hayagreeva
ಕಾಯಿ ಹುಳಿ/Kai Huli
ಕಾಜು ಬರ್ಫಿ/Kaju burfi
ಕಾಳು ಪಲ್ಯ/Kalu palya
ಕರ್ಬೂಜ ಮಿಲ್ಕ್ ಶೇಕ್/Karbooja milkshake
ಕಟ್ಟು ಸಾರು/Katt Saaru
ಕಟ್ಟು ಸಾರು/Kattu Saaru
ಕಾಯಿ ಚಟ್ನಿ/Kayi chutney
ಕೈಹುಲಿ/Kayihuli
ಕೆಂಪು ಚಟ್ನಿ/Kempu chutney
ಖಾರ ಬೂಂದಿ/Khara boondi
ಖಾರ ಬೂಂದಿ ಕಾಳು/Khara boondi kaalu
ಖಾರದ ಚಟ್ನಿ/Kharada chutney
ಖರ್ಜೂರ ಪಾಯಸ/Kharjura payasa
ಕೋಸಂಬರಿ/Kosambari
ಕೂರ್ಮ/Kurma
ಲಾಡು ಉಂಡೆ/Laadu unde
ಮದ್ದೂರು ವಡೆ/Maddur vade
ಮಜ್ಜಿಗೆ/Majjige
ಮಜ್ಜಿಗೆ ಹುಲಿ/Majjige huli
ಮಜ್ಜಿಗೆ ಮಸಾಲಾ/Majjige masala
ಮಂಡಕ್ಕಿ/Mandakki
ಮಾವಿನಮಿಡಿ ಉಪ್ಪಿನಕಾಯಿ/Mango Midi Pickle
ಮಸಾಲಾ ದೋಸೆ/Masala dose
ಮಸಾಲೆ ದೋಸೆ/Masale dose
ಮಸಾಲೆ ಪುರಿ/Masale puri
ಮಾವಿನಕಾಯಿ ಚಿತ್ರಾನ್ನ/Mavinakayi chitranna
ಮಾವಿನಕಾಯಿ ಗೊಜ್ಜು/Mavinakayi gojju
ಮೆಣಸಿನಕಾಯಿ ಬೋಂಡಾ/Menasinakayi bonda
ಮೆಂತ್ಯ ಬಾತ್/Mentya bath
ಮೆಂತ್ಯೆ ಚಪಾತಿ/Mentye Chapathi
ಹಾಲು/Milk
ಮಿರ್ಚಿ/Mirchi
ಮಿಶ್ರ ಸಾಂಬಾರ್/Mixed sambar
ಮಿಶ್ರ ತರಕಾರಿ ಸಾಂಬಾರ್/Mixed tarakari sambar
ಮಿಶ್ರ ತರಕಾರಿ ಕರಿ/Mixed vegetable curry
ಮಿಶ್ರ ತರಕಾರಿ ಸಾಂಬಾರ್/Mixed vegetable sambar
ಮೊಳಕೆ ಹೆಸರುಕಾಳು ಬೀನ್ಸ್ ಪಲ್ಯ/Molake hesarukalu beans palya
ಮೊಳಕೆ ಕೋಸಂಬರಿ/Molake kosambari
ಮೂಸಂಬಿ/Moosambi
ಮೊಸರನ್ನ/Mosaranna
ಮೊಸರು/Mosaru
ಮೊಸರು ಅವಲಕ್ಕಿ/Mosaru Avalakki
ಮೊಸರು ಬಜ್ಜಿ/Mosaru bajji
ನುಗ್ಗೆಕಾಯಿ ಸೊಪ್ಪು ಸಾಂಬಾರ್/Nuggekayi soppu sambar
ಈರುಳ್ಳಿ ಚಿತ್ರಾನ್ನ/Onion chitranna
ಒತ್ತು ಶಾವಿಗೆ ಗಸಗಸೆ ಪಾಯಸ/Ottu shavige gasagase payasa
ಪಾಲಕ ತಂಬುಳಿ/Palak tambuli
ಪಲಾವ್/Palav
ಪಲ್ಯ/Palya
ಪನೀರ್ ಬಟರ್ ಮಸಾಲಾ/Paneer butter masala
ಪನೀರ್ ಗ್ರೇವಿ/Paneer gravy
ಪನೀರ್ ಪಕೋಡ/Paneer pakoda
ಪಾನಿ ಪುರಿ/Pani puri
ಪಾನಿಪುರಿ/Panipuri
ಹಪ್ಪಳ/Papad
ಪೇಣಿ/Peni
ಪೇರಳೆ ಕೋಸಂಬರಿ/Perale kosambari
ಅನಾನಸ್ ಗೊಜ್ಜು/Pineapple gojju
ಅನಾನಸ್ ಸೂಪ್/Pineapple soup
ಪಿಸ್ತಾ ಐಸ್ಕ್ರೀಮ್/Pista icecream
ಪುಡಿ ಸಕ್ಕರೆ/Pudi sakkare
ಪುಳಿಯೋಗರೆ/Puliyogare
ಪುಳಿಯೊಗ್ಗರೆ/Puliyoggare
ರೈತಾ/Raita
ರಸಂ/Rasam
ರಸಾಯನ/Rasayana
ರಾಸ್ಮಲೈ/Rasmalai
ಅನ್ನ/Rice
ರೈಸ್ ಬಾತ್/Rice bath
ಸಾಗು/Saagu
ಸಾರು/Saaru
ಸಬ್ಬಕ್ಕಿ ಪಾಯಸ/Sabbakki payasa
ಸಾಂಬಾರ್/Sambar
ಸಾಂಬಾರು/Sambaru
ಸಂಡಿಗೆ/Sandige
ಸ್ಯಾಂಡ್ವಿಚ್ ಸ್ವೀಟ್/Sandwich sweet
ಸಾಸುವೆ ಚಿತ್ರಾನ್ನ/Sasuve chitranna
ಸೀಕರನೇ/Seekarane
ಸೀಮೆಕ್ಕಿ ಶಾವಿಗೆ ಪಾಯಸ/Seemeakki shavige payasa
ಶಾವಿಗೆ ಪಾಯಸ/Shavige payasa
ಶೇಂಗಾ ಕೋಸಂಬರಿ/Shenga kosambari
ಶೇಂಗಾ ಉಷಾಲಿ/Shenga ushali
ಸೋನ್ ಪಾಪಡಿ/Soan papadi
ಸಾಫ್ಟ್ ರೊಟ್ಟಿ/Soft roti
ಸೊಪ್ಪಿನ ಸಾಂಬಾರ್/Soppina sambar
ಸೌತೆಕಾಯಿ ಸಾಂಬಾರ್/Southekai Sambar
ಸೌತೆಕಾಯಿ ಮೊಸರು ಬಜ್ಜಿ/Southekayi mosaru bajji
ಸ್ವೀಟ್ ಕಾರ್ನ್ ಕೋಸಂಬರಿ/Sweetcorn kosambari
ತಾಳಿಪಟ್ಟು/Talipattu
ತಾಂಬೂಲ/Tambula
ತಾಂಬೂಲ ಚೀಲ/Tambula bag
ತರಕಾರಿ ಬಾತ್/Tarakari bath
ತರಕಾರಿ ಹುಳಿ/Tarakari huli
ತರಕಾರಿ ಪಾಳ್ಯ/Tarakari palya
ತೊವ್ವೆ/Tavve
ಚಹಾ/Tea
ತೆಂಗಿನಕಾಯಿ ಚಟ್ನಿ/Tenginakayi chutney
ತಿಳಿಸಾರು/Tilisaaru
ತೊಗರಿಬೇಳೆ ಚಟ್ನಿ/Togari bele chutney
ತೊವ್ವೆ/Tovve
ತುಪ್ಪಾ/Tuppa
ಉದ್ದಿನ ಒಗರೆ/Uddina ogare
ಉಪ್ಪಿನಕಾಯಿ/Uppinakayi
ಉಪ್ಪು/Uppu
ವಾಂಗಿಬಾತ್/Vangibath
ವೆಜ್ ಬಿರಿಯಾನಿ/Veg biriyani
ವೆಜ್ ಬೋಂಡಾ/Veg bonda
ವೆಜ್ ಕೊಲ್ಹಾಪುರಿ/Veg kolhapuri
ವೆಜ್ ಪಲಾವ್/Veg palav
ತರಕಾರಿ ಬೋಂಡಾ/Vegetable bonda
ತರಕಾರಿ ಪಲಾವ್/Vegetable palav
ತರಕಾರಿ ಸಲಾಡ್/Vegetable salad
ಬಿಳಿ ಅನ್ನ/White rice
`;

function inferCategory(english) {
  const e = english.toLowerCase();
  if (/(payasa|rasmalai|burfi|halwa|jamun|badusha|holige|ice|jilebi|laadu|laddu|sweet|papadi|chiroti|puri$|dumroot)/.test(e)) return 'Dessert';
  if (/(milk|coffee|tea|juice|punch|majjige|haalu|milkshake|moosambi)/.test(e)) return 'Beverage';
  if (/(bonda|ambode|vade|chips|beeda|boondi|sandige|happala|papad|pani puri|panipuri|mirchi|pakoda|mandakki)/.test(e)) return 'Snack';
  if (/(chutney|pickle|uppu|tuppa|benne|raita|kosambari|salad|gojju|saaru|rasam|huli|sambar|sambaru|sasive|tambuli|seekarane|tambula)/.test(e)) return 'Accompaniment';
  if (/(dose|dosa|idli|rotti|chapathi|talipattu|avalakki)/.test(e)) return 'South Indian';
  return 'Main Course';
}

function inferMeals(category, english) {
  const e = english.toLowerCase();
  if (category === 'Beverage') return e.includes('coffee') || e.includes('tea') ? ['Breakfast', 'Snack'] : ['Juice', 'Lunch', 'Dinner'];
  if (category === 'Snack') return ['Snack'];
  if (category === 'Dessert' || category === 'Accompaniment') return ['Lunch', 'Dinner'];
  if (category === 'South Indian' && /(dose|dosa|idli|avalakki|mandakki)/.test(e)) return ['Breakfast'];
  return ['Lunch', 'Dinner'];
}

const incomingItems = rawItems
  .split('\n')
  .map((line) => line.trim().replace(/,$/, ''))
  .filter(Boolean)
  .map((line) => {
    const slash = line.lastIndexOf('/');
    const kannada = line.slice(0, slash).trim();
    const english = line.slice(slash + 1).trim();
    const category = inferCategory(english);
    return { english, kannada, title: `${kannada}/${english}`, category, meals: inferMeals(category, english), veg: true };
  });

db.universal = db.universal || {};
db.universal.menuItems = db.universal.menuItems || [];
const menuItems = db.universal.menuItems;
let maxId = menuItems.reduce((max, item) => Math.max(max, Number(String(item.id || '').replace(/\D/g, '')) || 0), 0);
let added = 0;
let updated = 0;

for (const incoming of incomingItems) {
  const existing = menuItems.find((item) => item.english.toLowerCase() === incoming.english.toLowerCase());
  if (existing) {
    existing.kannada = incoming.kannada;
    existing.title = incoming.title;
    existing.category = existing.category || incoming.category;
    existing.meals = Array.isArray(existing.meals) && existing.meals.length ? existing.meals : incoming.meals;
    existing.veg = existing.veg !== false;
    updated += 1;
  } else {
    maxId += 1;
    menuItems.push({ id: `MNU-${String(maxId).padStart(3, '0')}`, ...incoming });
    added += 1;
  }
}

menuItems.sort((a, b) => a.english.localeCompare(b.english));
fs.writeFileSync(dbPath, `${JSON.stringify(db, null, 2)}\n`, 'utf8');
console.log(`Menu catalog now has ${menuItems.length} items. Added ${added}, updated ${updated}.`);
