#!/usr/bin/env python3
"""Insert webimage.tile.* and related error strings into every Localizable.strings bundle.

Idempotent: skips bundles that already contain ``webimage.tile.copyImage``.
Curated translations live in TRANSLATIONS; other locales are filled from
``tile_localization_generated.json`` or Google Translate (batch) on first run.

  python3 -m venv .venv-l10n && .venv-l10n/bin/pip install deep-translator
  .venv-l10n/bin/python Scripts/add_tile_localizations.py
"""

from __future__ import annotations

import json
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
RESOURCES = REPO_ROOT / "Packages/WebImagePicker/Sources/WebImagePicker/Resources"

MARKER_KEY = "webimage.tile.copyImage"

# fmt: off
TRANSLATIONS: dict[str, dict[str, str]] = {
    "en": {
        "webimage.tile.copyImage": "Copy Image",
        "webimage.tile.copyImageURL": "Copy Image URL",
        "webimage.tile.liftSubject": "Cut Out Subject",
        "webimage.tile.imageActions": "Image Actions",
        "webimage.tile.preview": "Preview",
        "webimage.tile.metadata": "Image Info",
        "webimage.tile.previewTitle": "Preview",
        "webimage.tile.metadataTitle": "Image Info",
        "webimage.tile.done": "Done",
        "webimage.tile.metadata.url": "URL",
        "webimage.tile.metadata.alt": "Alt text",
        "webimage.tile.metadata.title": "Title",
        "webimage.tile.metadata.recognizedText": "Recognized text",
        "webimage.tile.metadata.contentType": "Content type",
        "webimage.tile.metadata.dimensions": "Dimensions",
        "webimage.tile.metadata.loading": "Loading…",
        "webimage.tile.metadata.unknown": "Unknown",
        "webimage.error.pasteboardCopyFailed": "Could not copy to the clipboard.",
        "webimage.error.subjectLiftFailed": "Could not cut out the subject from this image.",
        "webimage.error.subjectLiftUnavailable": "Cut out subject is not available on this device.",
    },
    "es": {
        "webimage.tile.copyImage": "Copiar imagen",
        "webimage.tile.copyImageURL": "Copiar URL de la imagen",
        "webimage.tile.liftSubject": "Recortar sujeto",
        "webimage.tile.imageActions": "Acciones de imagen",
        "webimage.tile.preview": "Vista previa",
        "webimage.tile.metadata": "Información de la imagen",
        "webimage.tile.previewTitle": "Vista previa",
        "webimage.tile.metadataTitle": "Información de la imagen",
        "webimage.tile.done": "Listo",
        "webimage.tile.metadata.url": "URL",
        "webimage.tile.metadata.alt": "Texto alternativo",
        "webimage.tile.metadata.title": "Título",
        "webimage.tile.metadata.recognizedText": "Texto reconocido",
        "webimage.tile.metadata.contentType": "Tipo de contenido",
        "webimage.tile.metadata.dimensions": "Dimensiones",
        "webimage.tile.metadata.loading": "Cargando…",
        "webimage.tile.metadata.unknown": "Desconocido",
        "webimage.error.pasteboardCopyFailed": "No se pudo copiar al portapapeles.",
        "webimage.error.subjectLiftFailed": "No se pudo recortar el sujeto de esta imagen.",
        "webimage.error.subjectLiftUnavailable": "Recortar sujeto no está disponible en este dispositivo.",
    },
    "de": {
        "webimage.tile.copyImage": "Bild kopieren",
        "webimage.tile.copyImageURL": "Bild-URL kopieren",
        "webimage.tile.liftSubject": "Motiv freistellen",
        "webimage.tile.imageActions": "Bildaktionen",
        "webimage.tile.preview": "Vorschau",
        "webimage.tile.metadata": "Bildinfo",
        "webimage.tile.previewTitle": "Vorschau",
        "webimage.tile.metadataTitle": "Bildinfo",
        "webimage.tile.done": "Fertig",
        "webimage.tile.metadata.url": "URL",
        "webimage.tile.metadata.alt": "Alt-Text",
        "webimage.tile.metadata.title": "Titel",
        "webimage.tile.metadata.recognizedText": "Erkannter Text",
        "webimage.tile.metadata.contentType": "Inhaltstyp",
        "webimage.tile.metadata.dimensions": "Abmessungen",
        "webimage.tile.metadata.loading": "Laden…",
        "webimage.tile.metadata.unknown": "Unbekannt",
        "webimage.error.pasteboardCopyFailed": "Kopieren in die Zwischenablage fehlgeschlagen.",
        "webimage.error.subjectLiftFailed": "Motiv konnte nicht freigestellt werden.",
        "webimage.error.subjectLiftUnavailable": "Motiv freistellen ist auf diesem Gerät nicht verfügbar.",
    },
    "fr": {
        "webimage.tile.copyImage": "Copier l’image",
        "webimage.tile.copyImageURL": "Copier l’URL de l’image",
        "webimage.tile.liftSubject": "Détourer le sujet",
        "webimage.tile.imageActions": "Actions sur l’image",
        "webimage.tile.preview": "Aperçu",
        "webimage.tile.metadata": "Infos sur l’image",
        "webimage.tile.previewTitle": "Aperçu",
        "webimage.tile.metadataTitle": "Infos sur l’image",
        "webimage.tile.done": "Terminé",
        "webimage.tile.metadata.url": "URL",
        "webimage.tile.metadata.alt": "Texte alternatif",
        "webimage.tile.metadata.title": "Titre",
        "webimage.tile.metadata.recognizedText": "Texte reconnu",
        "webimage.tile.metadata.contentType": "Type de contenu",
        "webimage.tile.metadata.dimensions": "Dimensions",
        "webimage.tile.metadata.loading": "Chargement…",
        "webimage.tile.metadata.unknown": "Inconnu",
        "webimage.error.pasteboardCopyFailed": "Impossible de copier dans le presse-papiers.",
        "webimage.error.subjectLiftFailed": "Impossible de détourer le sujet de cette image.",
        "webimage.error.subjectLiftUnavailable": "Le détourage du sujet n’est pas disponible sur cet appareil.",
    },
    "it": {
        "webimage.tile.copyImage": "Copia immagine",
        "webimage.tile.copyImageURL": "Copia URL immagine",
        "webimage.tile.liftSubject": "Ritaglia soggetto",
        "webimage.tile.imageActions": "Azioni immagine",
        "webimage.tile.preview": "Anteprima",
        "webimage.tile.metadata": "Info immagine",
        "webimage.tile.previewTitle": "Anteprima",
        "webimage.tile.metadataTitle": "Info immagine",
        "webimage.tile.done": "Fine",
        "webimage.tile.metadata.url": "URL",
        "webimage.tile.metadata.alt": "Testo alternativo",
        "webimage.tile.metadata.title": "Titolo",
        "webimage.tile.metadata.recognizedText": "Testo riconosciuto",
        "webimage.tile.metadata.contentType": "Tipo di contenuto",
        "webimage.tile.metadata.dimensions": "Dimensioni",
        "webimage.tile.metadata.loading": "Caricamento…",
        "webimage.tile.metadata.unknown": "Sconosciuto",
        "webimage.error.pasteboardCopyFailed": "Impossibile copiare negli appunti.",
        "webimage.error.subjectLiftFailed": "Impossibile ritagliare il soggetto da questa immagine.",
        "webimage.error.subjectLiftUnavailable": "Il ritaglio del soggetto non è disponibile su questo dispositivo.",
    },
    "pt-BR": {
        "webimage.tile.copyImage": "Copiar imagem",
        "webimage.tile.copyImageURL": "Copiar URL da imagem",
        "webimage.tile.liftSubject": "Recortar assunto",
        "webimage.tile.imageActions": "Ações da imagem",
        "webimage.tile.preview": "Visualizar",
        "webimage.tile.metadata": "Informações da imagem",
        "webimage.tile.previewTitle": "Visualizar",
        "webimage.tile.metadataTitle": "Informações da imagem",
        "webimage.tile.done": "Concluído",
        "webimage.tile.metadata.url": "URL",
        "webimage.tile.metadata.alt": "Texto alternativo",
        "webimage.tile.metadata.title": "Título",
        "webimage.tile.metadata.recognizedText": "Texto reconhecido",
        "webimage.tile.metadata.contentType": "Tipo de conteúdo",
        "webimage.tile.metadata.dimensions": "Dimensões",
        "webimage.tile.metadata.loading": "Carregando…",
        "webimage.tile.metadata.unknown": "Desconhecido",
        "webimage.error.pasteboardCopyFailed": "Não foi possível copiar para a área de transferência.",
        "webimage.error.subjectLiftFailed": "Não foi possível recortar o assunto desta imagem.",
        "webimage.error.subjectLiftUnavailable": "Recortar assunto não está disponível neste dispositivo.",
    },
    "pt-PT": {
        "webimage.tile.copyImage": "Copiar imagem",
        "webimage.tile.copyImageURL": "Copiar URL da imagem",
        "webimage.tile.liftSubject": "Recortar assunto",
        "webimage.tile.imageActions": "Ações da imagem",
        "webimage.tile.preview": "Pré-visualização",
        "webimage.tile.metadata": "Informação da imagem",
        "webimage.tile.previewTitle": "Pré-visualização",
        "webimage.tile.metadataTitle": "Informação da imagem",
        "webimage.tile.done": "Concluído",
        "webimage.tile.metadata.url": "URL",
        "webimage.tile.metadata.alt": "Texto alternativo",
        "webimage.tile.metadata.title": "Título",
        "webimage.tile.metadata.recognizedText": "Texto reconhecido",
        "webimage.tile.metadata.contentType": "Tipo de conteúdo",
        "webimage.tile.metadata.dimensions": "Dimensões",
        "webimage.tile.metadata.loading": "A carregar…",
        "webimage.tile.metadata.unknown": "Desconhecido",
        "webimage.error.pasteboardCopyFailed": "Não foi possível copiar para a área de transferência.",
        "webimage.error.subjectLiftFailed": "Não foi possível recortar o assunto desta imagem.",
        "webimage.error.subjectLiftUnavailable": "Recortar assunto não está disponível neste dispositivo.",
    },
    "ja": {
        "webimage.tile.copyImage": "画像をコピー",
        "webimage.tile.copyImageURL": "画像URLをコピー",
        "webimage.tile.liftSubject": "被写体を切り抜く",
        "webimage.tile.imageActions": "画像の操作",
        "webimage.tile.preview": "プレビュー",
        "webimage.tile.metadata": "画像情報",
        "webimage.tile.previewTitle": "プレビュー",
        "webimage.tile.metadataTitle": "画像情報",
        "webimage.tile.done": "完了",
        "webimage.tile.metadata.url": "URL",
        "webimage.tile.metadata.alt": "代替テキスト",
        "webimage.tile.metadata.title": "タイトル",
        "webimage.tile.metadata.recognizedText": "認識されたテキスト",
        "webimage.tile.metadata.contentType": "コンテンツタイプ",
        "webimage.tile.metadata.dimensions": "寸法",
        "webimage.tile.metadata.loading": "読み込み中…",
        "webimage.tile.metadata.unknown": "不明",
        "webimage.error.pasteboardCopyFailed": "クリップボードにコピーできませんでした。",
        "webimage.error.subjectLiftFailed": "この画像から被写体を切り抜けませんでした。",
        "webimage.error.subjectLiftUnavailable": "このデバイスでは被写体の切り抜きは利用できません。",
    },
    "ko": {
        "webimage.tile.copyImage": "이미지 복사",
        "webimage.tile.copyImageURL": "이미지 URL 복사",
        "webimage.tile.liftSubject": "피사체 잘라내기",
        "webimage.tile.imageActions": "이미지 작업",
        "webimage.tile.preview": "미리보기",
        "webimage.tile.metadata": "이미지 정보",
        "webimage.tile.previewTitle": "미리보기",
        "webimage.tile.metadataTitle": "이미지 정보",
        "webimage.tile.done": "완료",
        "webimage.tile.metadata.url": "URL",
        "webimage.tile.metadata.alt": "대체 텍스트",
        "webimage.tile.metadata.title": "제목",
        "webimage.tile.metadata.recognizedText": "인식된 텍스트",
        "webimage.tile.metadata.contentType": "콘텐츠 유형",
        "webimage.tile.metadata.dimensions": "크기",
        "webimage.tile.metadata.loading": "로드 중…",
        "webimage.tile.metadata.unknown": "알 수 없음",
        "webimage.error.pasteboardCopyFailed": "클립보드에 복사할 수 없습니다.",
        "webimage.error.subjectLiftFailed": "이 이미지에서 피사체를 잘라낼 수 없습니다.",
        "webimage.error.subjectLiftUnavailable": "이 기기에서는 피사체 잘라내기를 사용할 수 없습니다.",
    },
    "zh-Hans": {
        "webimage.tile.copyImage": "拷贝图像",
        "webimage.tile.copyImageURL": "拷贝图像 URL",
        "webimage.tile.liftSubject": "抠出主体",
        "webimage.tile.imageActions": "图像操作",
        "webimage.tile.preview": "预览",
        "webimage.tile.metadata": "图像信息",
        "webimage.tile.previewTitle": "预览",
        "webimage.tile.metadataTitle": "图像信息",
        "webimage.tile.done": "完成",
        "webimage.tile.metadata.url": "URL",
        "webimage.tile.metadata.alt": "替代文本",
        "webimage.tile.metadata.title": "标题",
        "webimage.tile.metadata.recognizedText": "识别的文本",
        "webimage.tile.metadata.contentType": "内容类型",
        "webimage.tile.metadata.dimensions": "尺寸",
        "webimage.tile.metadata.loading": "正在加载…",
        "webimage.tile.metadata.unknown": "未知",
        "webimage.error.pasteboardCopyFailed": "无法复制到剪贴板。",
        "webimage.error.subjectLiftFailed": "无法从此图像中抠出主体。",
        "webimage.error.subjectLiftUnavailable": "此设备不支持抠出主体。",
    },
    "zh-Hant": {
        "webimage.tile.copyImage": "拷貝圖像",
        "webimage.tile.copyImageURL": "拷貝圖像 URL",
        "webimage.tile.liftSubject": "去背主體",
        "webimage.tile.imageActions": "圖像操作",
        "webimage.tile.preview": "預覽",
        "webimage.tile.metadata": "圖像資訊",
        "webimage.tile.previewTitle": "預覽",
        "webimage.tile.metadataTitle": "圖像資訊",
        "webimage.tile.done": "完成",
        "webimage.tile.metadata.url": "URL",
        "webimage.tile.metadata.alt": "替代文字",
        "webimage.tile.metadata.title": "標題",
        "webimage.tile.metadata.recognizedText": "辨識的文字",
        "webimage.tile.metadata.contentType": "內容類型",
        "webimage.tile.metadata.dimensions": "尺寸",
        "webimage.tile.metadata.loading": "載入中…",
        "webimage.tile.metadata.unknown": "未知",
        "webimage.error.pasteboardCopyFailed": "無法拷貝到剪貼板。",
        "webimage.error.subjectLiftFailed": "無法從此圖像去背主體。",
        "webimage.error.subjectLiftUnavailable": "此裝置不支援去背主體。",
    },
    "ru": {
        "webimage.tile.copyImage": "Копировать изображение",
        "webimage.tile.copyImageURL": "Копировать URL изображения",
        "webimage.tile.liftSubject": "Вырезать объект",
        "webimage.tile.imageActions": "Действия с изображением",
        "webimage.tile.preview": "Просмотр",
        "webimage.tile.metadata": "Сведения об изображении",
        "webimage.tile.previewTitle": "Просмотр",
        "webimage.tile.metadataTitle": "Сведения об изображении",
        "webimage.tile.done": "Готово",
        "webimage.tile.metadata.url": "URL",
        "webimage.tile.metadata.alt": "Альтернативный текст",
        "webimage.tile.metadata.title": "Заголовок",
        "webimage.tile.metadata.recognizedText": "Распознанный текст",
        "webimage.tile.metadata.contentType": "Тип содержимого",
        "webimage.tile.metadata.dimensions": "Размеры",
        "webimage.tile.metadata.loading": "Загрузка…",
        "webimage.tile.metadata.unknown": "Неизвестно",
        "webimage.error.pasteboardCopyFailed": "Не удалось скопировать в буфер обмена.",
        "webimage.error.subjectLiftFailed": "Не удалось вырезать объект на этом изображении.",
        "webimage.error.subjectLiftUnavailable": "Вырезание объекта недоступно на этом устройстве.",
    },
    "ar": {
        "webimage.tile.copyImage": "نسخ الصورة",
        "webimage.tile.copyImageURL": "نسخ عنوان URL للصورة",
        "webimage.tile.liftSubject": "قصّ الموضوع",
        "webimage.tile.imageActions": "إجراءات الصورة",
        "webimage.tile.preview": "معاينة",
        "webimage.tile.metadata": "معلومات الصورة",
        "webimage.tile.previewTitle": "معاينة",
        "webimage.tile.metadataTitle": "معلومات الصورة",
        "webimage.tile.done": "تم",
        "webimage.tile.metadata.url": "URL",
        "webimage.tile.metadata.alt": "النص البديل",
        "webimage.tile.metadata.title": "العنوان",
        "webimage.tile.metadata.recognizedText": "النص المعروف",
        "webimage.tile.metadata.contentType": "نوع المحتوى",
        "webimage.tile.metadata.dimensions": "الأبعاد",
        "webimage.tile.metadata.loading": "جارٍ التحميل…",
        "webimage.tile.metadata.unknown": "غير معروف",
        "webimage.error.pasteboardCopyFailed": "تعذّر النسخ إلى الحافظة.",
        "webimage.error.subjectLiftFailed": "تعذّر قصّ الموضوع من هذه الصورة.",
        "webimage.error.subjectLiftUnavailable": "قصّ الموضوع غير متاح على هذا الجهاز.",
    },
    "nl": {
        "webimage.tile.copyImage": "Afbeelding kopiëren",
        "webimage.tile.copyImageURL": "Afbeeldings-URL kopiëren",
        "webimage.tile.liftSubject": "Onderwerp uitknippen",
        "webimage.tile.imageActions": "Afbeeldingsacties",
        "webimage.tile.preview": "Voorbeeld",
        "webimage.tile.metadata": "Afbeeldingsinfo",
        "webimage.tile.previewTitle": "Voorbeeld",
        "webimage.tile.metadataTitle": "Afbeeldingsinfo",
        "webimage.tile.done": "Gereed",
        "webimage.tile.metadata.url": "URL",
        "webimage.tile.metadata.alt": "Alt-tekst",
        "webimage.tile.metadata.title": "Titel",
        "webimage.tile.metadata.recognizedText": "Herkende tekst",
        "webimage.tile.metadata.contentType": "Inhoudstype",
        "webimage.tile.metadata.dimensions": "Afmetingen",
        "webimage.tile.metadata.loading": "Laden…",
        "webimage.tile.metadata.unknown": "Onbekend",
        "webimage.error.pasteboardCopyFailed": "Kopiëren naar het klembord is mislukt.",
        "webimage.error.subjectLiftFailed": "Kon het onderwerp niet uitknippen uit deze afbeelding.",
        "webimage.error.subjectLiftUnavailable": "Onderwerp uitknippen is niet beschikbaar op dit apparaat.",
    },
}
# fmt: on

LOCALE_ALIASES: dict[str, str] = {
    "en-AU": "en",
    "en-CA": "en",
    "en-GB": "en",
    "en-IN": "en",
    "de-AT": "de",
    "de-CH": "de",
    "es-MX": "es",
    "es-419": "es",
    "fr-CA": "fr",
    "it-CH": "it",
    "nl-BE": "nl",
    "zh-TW": "zh-Hant",
    "zh-HK": "zh-Hant",
    "ar-AE": "ar",
}

# Google Translate target codes for locales not in TRANSLATIONS.
GOOGLE_LOCALE: dict[str, str] = {
    "af": "af",
    "az": "az",
    "be": "be",
    "bg": "bg",
    "bn": "bn",
    "bs": "bs",
    "ca": "ca",
    "cs": "cs",
    "cy": "cy",
    "da": "da",
    "el": "el",
    "et": "et",
    "eu": "eu",
    "fa": "fa",
    "fi": "fi",
    "fil": "tl",
    "ga": "ga",
    "gl": "gl",
    "gu": "gu",
    "he": "iw",
    "hi": "hi",
    "hr": "hr",
    "hu": "hu",
    "hy": "hy",
    "id": "id",
    "is": "is",
    "kk": "kk",
    "km": "km",
    "kn": "kn",
    "ky": "ky",
    "lo": "lo",
    "lt": "lt",
    "lv": "lv",
    "mk": "mk",
    "ml": "ml",
    "mn": "mn",
    "mr": "mr",
    "ms": "ms",
    "mt": "mt",
    "my": "my",
    "nb": "no",
    "ne": "ne",
    "or": "or",
    "pa": "pa",
    "pl": "pl",
    "ro": "ro",
    "si": "si",
    "sk": "sk",
    "sl": "sl",
    "sq": "sq",
    "sr": "sr",
    "sv": "sv",
    "sw": "sw",
    "ta": "ta",
    "te": "te",
    "th": "th",
    "tk": "tk",
    "tr": "tr",
    "uk": "uk",
    "ur": "ur",
    "uz": "uz",
    "vi": "vi",
    "zu": "zu",
}

GENERATED_CACHE = Path(__file__).with_name("tile_localization_generated.json")


def google_target(locale: str) -> str:
    if locale in GOOGLE_LOCALE:
        return GOOGLE_LOCALE[locale]
    return locale.split("-", 1)[0]


def load_generated_cache() -> dict[str, dict[str, str]]:
    if not GENERATED_CACHE.exists():
        return {}
    return json.loads(GENERATED_CACHE.read_text(encoding="utf-8"))


def save_generated_cache(cache: dict[str, dict[str, str]]) -> None:
    GENERATED_CACHE.write_text(
        json.dumps(cache, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def translate_locale(locale: str, cache: dict[str, dict[str, str]]) -> dict[str, str]:
    if locale in cache:
        return cache[locale]
    try:
        from deep_translator import GoogleTranslator
    except ImportError as exc:
        raise SystemExit(
            "Install deep-translator to generate missing locales: pip install deep-translator"
        ) from exc

    target = google_target(locale)
    source = TRANSLATIONS["en"]
    keys = list(source.keys())
    values = [source[k] for k in keys]
    translator = GoogleTranslator(source="en", target=target)
    batch = translator.translate_batch(values)
    if len(batch) != len(keys):
        raise RuntimeError(f"translate_batch size mismatch for {locale}")
    translated = dict(zip(keys, batch, strict=True))
    cache[locale] = translated
    print(f"translated {locale} -> {target}", flush=True)
    return translated


def resolve_locale(locale: str, cache: dict[str, dict[str, str]]) -> dict[str, str]:
    if locale in TRANSLATIONS:
        return TRANSLATIONS[locale]
    if locale in LOCALE_ALIASES:
        return TRANSLATIONS[LOCALE_ALIASES[locale]]
    base = locale.split("-", 1)[0]
    if base in TRANSLATIONS:
        return TRANSLATIONS[base]
    if base in LOCALE_ALIASES:
        return TRANSLATIONS[LOCALE_ALIASES[base]]
    if locale in cache:
        return cache[locale]
    if base in cache:
        return cache[base]
    return translate_locale(locale if locale in GOOGLE_LOCALE else base, cache)


def format_block(strings: dict[str, str]) -> str:
    keys = list(TRANSLATIONS["en"].keys())
    lines = [f'"{k}" = "{strings[k]}";' for k in keys]
    return "\n".join(lines) + "\n"


def patch_file(path: Path, block: str) -> bool:
    text = path.read_text(encoding="utf-8")
    if MARKER_KEY in text:
        return False
    match = re.search(
        r'^"webimage\.searchPlaceholder"\s*=\s*".*?";\s*\n',
        text,
        flags=re.MULTILINE,
    )
    if not match:
        raise SystemExit(f"searchPlaceholder not found in {path}")
    insert_at = match.end()
    new_text = text[:insert_at] + block + text[insert_at:]
    path.write_text(new_text, encoding="utf-8")
    return True


def main() -> None:
    cache = load_generated_cache()
    updated = 0
    skipped = 0
    for lproj in sorted(RESOURCES.glob("*.lproj")):
        locale = lproj.name.removesuffix(".lproj")
        strings = resolve_locale(locale, cache)
        path = lproj / "Localizable.strings"
        if patch_file(path, format_block(strings)):
            updated += 1
            print(f"updated {locale}")
        else:
            skipped += 1
    save_generated_cache(cache)
    print(f"done: {updated} updated, {skipped} skipped")


if __name__ == "__main__":
    main()
