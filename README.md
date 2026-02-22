<p align="center">
  <img src="assets/quantum.jpg" width="160" />
</p>

<h1 align="center">KET Studio</h1>

<p align="center">
  <b>Kvant hisoblash va ilmiy vizualizatsiya uchun professional Event-Driven IDE</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Windows-blue?style=for-the-badge&logo=windows" />
  <img src="https://img.shields.io/badge/Version-v0.2.0--alpha-orange?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Language-Python%20%7C%20Dart-green?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Status-Active%20Development-purple?style=for-the-badge" />
</p>

---

## 🚀 Loyiha Haqida

**KET Studio** — bu kvant hisoblash tadqiqotlari va ilmiy dasturlash uchun maxsus ishlab chiqilgan professional ishchi muhit (IDE). U kod yozish va natijani ko'rish jarayonini uzviy bog'lab, real vaqt rejimida yuqori sifatli vizualizatsiya hamda sessiyalar tarixini boshqarish imkonini beradi.

Dastur shunchaki matnli loglarni o'qish bilan cheklanib qolmay, kodingizdan kelayotgan ma'lumotlarni interaktiv grafiklar, matritsalar va jadvallar ko'rinishida taqdim etadi.

---

## 🧠 Dastur Qanday Ishlaydi?

KET Studio **Event-Driven (Voqealarga asoslangan)** arxitektura tamoyili asosida ishlaydi. 

1. **Ijro (Execution):** Siz yozgan Python kodi alohida jarayon (process) sifatida ishga tushadi.
2. **Kuzatuv (Interception):** IDE kodingizdan chiqayotgan `stdout` (standard chiqish) oqimini real vaqtda kuzatib boradi.
3. **Protokol:** Agar kodingizda maxsus `KET_VIZ` prefiksi bilan boshlangan JSON xabarlar paydo bo'lsa, IDE ularni "vizualizatsiya voqeasi" sifatida taniydi.
4. **Rendering:** Olingan ma'lumotlar vizualizatsiya panelida mos komponent (Gistogramma, Heatmap, Text va h.k.) orqali chizib beriladi.

---

## 🛠 Nimaga Asoslangan?

Dastur eng zamonaviy texnologiyalar yig'indisidan tashkil topgan:

*   **Frontend (UI):** [Flutter](https://flutter.dev/) (Dart) — Yuqori samaradorlik va Windows platformasida "native" interfeys tajribasi.
*   **Backend (Engine):** [Python 3.10+](https://www.python.org/) — Ilmiy hisoblashlar va kvant algoritmlarini bajarish uchun asosiy vosita.
*   **Ma'lumotlar oqimi:** Stream-based terminal emulation va asynchronous JSON processing.
*   **Dizayn:** Microsoft Fluent Design tizimiga asoslangan interfeys.

---

## 📊 Vizualizatsiya Paneliga Ma'lumot Uzatish

Dastur kodingizdan panelga ma'lumot uzatishning uch xil professional usulini taqdim etadi:

### 1. `ket_viz` Modulidan Foydalanish (Tavsiya etiladi)
IDE kodingiz ishga tushishi bilan loyiha papkasiga virtual `ket_viz.py` modulini ineksiya qiladi. Undan foydalanish juda oddiy:

```python
import ket_viz

# 1. Gistogramma (Kvant o'lchov natijalari uchun)
counts = {"00": 480, "01": 20, "10": 30, "11": 494}
ket_viz.histogram(counts, title="Bell State Results")

# 2. Heatmap (Zichlik matritsalari uchun)
matrix = [[0.8, 0.1], [0.1, 0.0]]
ket_viz.heatmap(matrix, title="Density Matrix")

# 3. Professional Jadvallar
data = [["Parametr", "Qiymat"], ["Qubits", 2], ["Shots", 1024]]
ket_viz.table("Simulyatsiya Tafsilotlari", data)
```

### 2. Matplotlib Avtomatik Interfetsiya
Agar kodingizda `matplotlib.pyplot` ishlatilgan bo'lsa, siz hech qanday kod o'zgartirishingiz shart emas. IDE `plt.show()` komandasini avtomatik ushlab oladi va natijani rasm (image) ko'rinishida panelga chiqaradi.

### 3. Protokol Orqali Uzatish (Raw Protocol)
Har qanday dasturlash tilidan quyidagi formatda matn chiqarish orqali panelni boshqarish mumkin:
`KET_VIZ {"kind": "text", "payload": {"content": "Salom Dunyo"}}`

---

## 💎 Professional Foydalanish Bo'yicha Ko'rsatmalar

1.  **Python Sozlamalari:**
    *   `Settings` paneliga o'ting va kompyuteringizdagi Python interpreter yo'lini (`python.exe`) ko'rsating.
2.  **Kutubxonalar Boshqaruvi:**
    *   `Help -> Packages` menyusi orqali kerakli kutubxonalarni (`qiskit`, `numpy`, `matplotlib`) to'g'ridan-to'g'ri IDE orqali o'rnating.
3.  **Loyiha Strukturasi:**
    *   Loyihangizda `.py` faylini yarating.
    *   Kodingizda vizualizatsiya funksiyalaridan foydalaning.
    *   `Run` tugmasini bosing va o'ng tarafdagi **Visualization** panelida natijalarni kuzating.
4.  **Tarixni Kuzatish:**
    *   Har bir kod ijrosi alohida sessiya sifatida saqlanadi. Panelning chap tarafidagi tarix tugmasi orqali avvalgi natijalarga qaytishingiz mumkin.

---

## 📋 Qo'llab-quvvatlanadigan Vizualizatsiya Turlari

*   **`text`**: Boyitilgan matnli loglar.
*   **`table`**: Ma'lumotlar jadvali.
*   **`heatmap`**: Matritsa va issiqlik xaritalari.
*   **`histogram`**: Statistik taqsimotlar.
*   **`image/circuit`**: Chizmalar, plots va sxemalar.
*   **`metrics`**: Real vaqt rejimida o'zgaruvchi ko'rsatkichlar.
*   **`error`**: Python xatolarining chiroyli va tushunarli ko'rinishi.

---

## � Qo'shimcha Hujjatlar va Namunalar

*   **[Event Schema Spec](docs/event_schema.md)**: Vizualizatsiya protokoli bo'yicha to'liq texnik spetsifikatsiya.
*   **[Misollar (Examples)](examples/)**: 
    *   `bell_state.py`: Bell holatini simulyatsiya qilish va vizualizatsiya.
    *   `grover_search.py`: Grover algoritmi va uning bosqichlari.
    *   `phase_evolution.py`: Kvant holati fazasining vaqt bo'yicha o'zgarishi (Phase Color Evolution).

---

## �📜 Litsenziya

MIT Litsenziyasi ostida tarqatiladi. KET Studio kvant ekotizimini rivojlantirish uchun ochiq manbali loyiha hisoblanadi.

---
<p align="center"> 
  <b>KET Studio — Kvant kelajagi sari intiluvchan muhandislar tanlovi.</b> 
</p>