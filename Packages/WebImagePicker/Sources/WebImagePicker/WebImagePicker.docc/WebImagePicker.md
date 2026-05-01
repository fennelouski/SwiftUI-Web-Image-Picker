# ``WebImagePicker``

Browse and pick images discovered on a web page, with a Photos-style sheet, configurable extraction, and typed results.

@Metadata {
    @TechnologyRoot()
}

## Overview

Add the library to your app target, then present ``WebImagePicker`` or use the ``View/webImagePicker(isPresented:configuration:onPick:)`` modifier. Configure behavior with ``WebImagePickerConfiguration`` (including ``WebImageExtractionMode``). User choices are delivered as ``WebImageSelection`` values containing raw bytes, optional MIME type, and source URL.

On Apple platforms, use ``WebImageSelection/makeUIImage()`` or ``WebImageSelection/makeNSImage()`` to decode platform images when available.

## Topics

### Essentials

- ``WebImagePicker``
- ``View/webImagePicker(isPresented:configuration:onPick:)``

### Configuration

- ``WebImagePickerConfiguration``
- ``WebImageExtractionMode``

### Selection

- ``WebImageSelection``

### Articles

- <doc:GettingStarted>
