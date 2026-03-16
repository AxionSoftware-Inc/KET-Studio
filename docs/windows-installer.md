# Windows installer

`MSIX` bu loyiha uchun hozircha tarqatish formati sifatida yaramaydi, chunki build qilingan paket `Msix Testing` self-signed sertifikat bilan sign qilingan. Boshqa kompyuterlarda shu sertifikat trusted bo'lmagani uchun Windows installer oynasida `Install` tugmasi bloklanadi yoki signature xatosi chiqadi.

Shu sabab repo ichida `.exe` installer uchun `Inno Setup` pipeline qo'shildi.

## Nima kerak

1. Flutter Windows build ishlashi kerak.
2. `git` PATH ichida bo'lishi kerak.
3. Inno Setup 6 o'rnatilgan bo'lishi kerak.

Default compiler yo'llari:

- `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`
- `C:\Program Files\Inno Setup 6\ISCC.exe`

## Installer build qilish

Repo root ichida:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_windows_installer.ps1
```

Bu script quyidagini qiladi:

1. `flutter build windows --release`
2. `build\windows\x64\runner\Release` ichidagi fayllarni yig'adi
3. Inno Setup orqali install qilinadigan `.exe` yaratadi

Natija shu yerga chiqadi:

```text
dist\windows-installer\
```

## Tayyor installer xususiyatlari

- `KET Studio` ni Windows'da normal uninstall qilinadigan dastur sifatida o'rnatadi
- Start Menu shortcut yaratadi
- xohishga ko'ra desktop shortcut yaratadi
- admin huquqisiz, current user uchun o'rnatiladi

## Agar kelajakda MSIX kerak bo'lsa

`MSIX` faqat quyidagi holatda professional tarzda tarqatiladi:

1. haqiqiy code-signing sertifikat olinadi
2. `Publisher` manifestdagi subject bilan bir xil qilinadi
3. paket o'sha sertifikat bilan sign qilinadi

Shundan keyingina boshqa kompyuterlarda `Install` tugmasi normal ishlaydi.
