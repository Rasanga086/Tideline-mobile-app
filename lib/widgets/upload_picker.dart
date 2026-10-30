import 'dart:io' show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../core/uploads.dart';

/// Opens the system file picker for PDF/JPG/PNG account documents.
Future<List<PickedUpload>> pickDocuments() async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
  );
  return [for (final f in files) await _documentFrom(f)];
}

Future<Uint8List> _readAll(PlatformFile f) async {
  try {
    return await f.readAsBytes();
  } catch (_) {
    final chunks = await f.readAsByteStream().toList();
    return Uint8List.fromList([for (final c in chunks) ...c]);
  }
}

Future<PickedUpload> _documentFrom(PlatformFile f) async {
  var name = f.name;
  final path = kIsWeb ? null : f.path;
  Uint8List? bytes;
  if (path == null) {
    // No plain file path (web, or a content:// URI): hold the contents instead.
    try {
      bytes = await _readAll(f);
    } catch (_) {
      throw PickFailure('Could not read $name. Try picking it again.');
    }
  }
  final size = bytes?.length ?? await f.length() ?? 0;
  if (!documentContentTypes.containsKey(extensionOf(name))) {
    // Some pickers return names with no extension; judge by content instead.
    final head =
        bytes ?? await File(path!).openRead(0, 8).expand((c) => c).toList();
    final ext = sniffDocumentExtension(head);
    if (ext != null) name = '$name.$ext';
  }
  return PickedUpload(name: name, size: size, path: path, bytes: bytes);
}

/// Opens the photo library.
Future<List<PickedUpload>> pickImages({
  ImagePicker? picker,
  bool multiple = true,
}) async {
  final p = picker ?? ImagePicker();
  final List<XFile> files;
  if (multiple) {
    files = await p.pickMultiImage();
  } else {
    final one = await p.pickImage(source: ImageSource.gallery);
    files = [?one];
  }
  return [
    for (final f in files)
      PickedUpload(
        name: f.name,
        size: await f.length(),
        path: kIsWeb ? null : f.path,
        bytes: kIsWeb ? await f.readAsBytes() : null,
      ),
  ];
}

/// A labelled list of chosen files with an "Add" button and per-file remove.
/// [check] returns an error message for a file the API would reject; those are
/// reported in the field instead of being added.
class UploadPicker extends StatefulWidget {
  const UploadPicker({
    super.key,
    required this.label,
    required this.files,
    required this.pick,
    required this.check,
    required this.max,
    this.hint,
    this.enabled = true,
    this.icon = Icons.attach_file,
    this.onChanged,
    this.error,
  });

  final String label;
  final String? hint;
  final List<PickedUpload> files;
  final Future<List<PickedUpload>> Function() pick;
  final String? Function(String name, int size) check;
  final int max;
  final bool enabled;
  final IconData icon;

  /// Called after files are added or removed, so the form can refresh what depends on them.
  final VoidCallback? onChanged;

  /// A problem to show under the list (e.g. "attach at least one file").
  final String? error;

  @override
  State<UploadPicker> createState() => _UploadPickerState();
}

class _UploadPickerState extends State<UploadPicker> {
  String? _problem;

  Future<void> _add() async {
    try {
      final picked = await widget.pick();
      final problems = <String>[];
      for (final f in picked) {
        final err = widget.check(f.name, f.size);
        if (err != null) {
          problems.add(err);
        } else if (widget.files.length >= widget.max) {
          problems.add('You can attach up to ${widget.max}.');
          break;
        } else {
          widget.files.add(f);
        }
      }
      if (mounted) {
        setState(
          () => _problem = problems.isEmpty ? null : problems.join('\n'),
        );
        widget.onChanged?.call();
      }
    } on PickFailure catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } catch (_) {
      if (mounted) setState(() => _problem = 'Could not open your files.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: text.titleMedium),
        if (widget.hint != null) Text(widget.hint!, style: text.bodySmall),
        for (var i = 0; i < widget.files.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: _Preview(widget.files[i], fallback: widget.icon),
            title: Text(widget.files[i].name, overflow: TextOverflow.ellipsis),
            subtitle: Text(_sizeLabel(widget.files[i].size)),
            trailing: IconButton(
              tooltip: 'Remove ${widget.files[i].name}',
              icon: const Icon(Icons.close),
              onPressed: widget.enabled
                  ? () {
                      setState(() => widget.files.removeAt(i));
                      widget.onChanged?.call();
                    }
                  : null,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.enabled ? _add : null,
            icon: const Icon(Icons.add),
            label: Text(
              widget.files.isEmpty
                  ? 'Add'
                  : 'Add more (${widget.files.length}/${widget.max})',
            ),
          ),
        ),
        if (_problem != null)
          Text(
            _problem!,
            style: const TextStyle(color: TL.coral700, fontSize: 13),
          ),
        if (widget.error != null)
          Text(
            widget.error!,
            style: const TextStyle(color: TL.coral700, fontSize: 13),
          ),
      ],
    );
  }
}

String _sizeLabel(int bytes) => bytes <= 0
    ? ''
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).ceil()} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// A thumbnail for photos and a file icon for PDFs and anything that cannot be drawn.
class _Preview extends StatelessWidget {
  const _Preview(this.file, {required this.fallback});
  final PickedUpload file;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final ext = extensionOf(file.name);
    final isImage = ext == 'jpg' || ext == 'jpeg' || ext == 'png';
    ImageProvider? provider;
    if (isImage && file.bytes != null) {
      provider = MemoryImage(file.bytes!);
    } else if (isImage && file.path != null && !kIsWeb) {
      provider = FileImage(File(file.path!));
    }
    if (provider == null) {
      return Icon(
        ext == 'pdf' ? Icons.picture_as_pdf_outlined : fallback,
        color: TL.sea600,
        size: 32,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Image(
          image: provider,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Icon(fallback, color: TL.sea600),
        ),
      ),
    );
  }
}
