import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, this.pickPostImage});

  /// Allows a host or a widget test to provide its own gallery picker.
  final Future<XFile?> Function()? pickPostImage;

  @override
  State<CommunityScreen> createState() => CommunityScreenState();
}

class CommunityScreenState extends State<CommunityScreen> {
  final posts = demoPosts();
  int filter = 0;

  Future<void> createPost() async {
    final result = await showModalBottomSheet<Post>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _PostComposer(pickImage: widget.pickPostImage),
    );
    if (result != null && mounted) {
      setState(() {
        posts.insert(0, result);
        filter = 0;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Нийтлэл нэмэгдлээ')));
    }
  }

  Future<void> showComments(Post post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _CommentsSheet(post: post),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visible = posts.where(
      (p) => filter == 0 || p.category == PostCategory.values[filter - 1],
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        const Text(
          'Оюутнуудын орчин',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Кампусын яриа эндээс эхэлнэ ✨',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        _CommunityBanner(onCreate: createPost),
        const SizedBox(height: 22),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              PostCategory.values.length + 1,
              (index) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    index == 0 ? 'Бүгд' : PostCategory.values[index - 1].label,
                  ),
                  selected: filter == index,
                  onSelected: (_) => setState(() => filter = index),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Энэ төрөлд зар хараахан алга. Эхний зарыг оруулаарай.',
              textAlign: TextAlign.center,
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= 340 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.3
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                for (final post in visible)
                  SizedBox(
                    width: width,
                    child: _PostCard(
                      post: post,
                      onLike: () => setState(() {
                        post.liked = !post.liked;
                        post.likes += post.liked ? 1 : -1;
                      }),
                      onComments: () => showComments(post),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CommunityBanner extends StatelessWidget {
  const _CommunityBanner({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.purple, Color(0xFF9D66EE)],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -25,
          top: -35,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .12),
                width: 28,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Хуваалцъя. Холбогдъё.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Ном, шинэ санаа, хэрэгтэй зөвлөгөө.\nЧиний оюутны хүрээлэл.',
                style: TextStyle(
                  color: Color(0xFFEDE1FF),
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 15),
              FilledButton.icon(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.purple,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Хуваалцах'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onComments,
  });
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = switch (post.category) {
      PostCategory.sale => dark ? AppColors.lavender : AppColors.purple,
      PostCategory.exchange => const Color(0xFF277F74),
      PostCategory.rental => const Color(0xFFB86B23),
      PostCategory.question =>
        dark ? const Color(0xFFF299C4) : const Color(0xFFBE4B89),
      PostCategory.teacher => const Color(0xFF277F74),
    };
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return SurfaceCard(
      padding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              post.category.label,
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (post.imageBytes != null) ...[
            Semantics(
              button: true,
              label: '${post.title} зургийг томруулах',
              child: InkWell(
                key: const ValueKey('open-post-image'),
                onTap: () => _showPostImage(context, post),
                borderRadius: BorderRadius.circular(18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.memory(
                    post.imageBytes!,
                    key: const ValueKey('post-image'),
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                    semanticLabel: post.title,
                    errorBuilder: (_, error, stackTrace) => const SizedBox(
                      height: 120,
                      child: Center(
                        child: Text('Зураг харуулах боломжгүй байна'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              key: const ValueKey('post-avatar'),
              height: 140,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: .08),
                    accent.withValues(alpha: .23),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Semantics(
                label: post.avatar.label,
                child: post.avatar.assetPath != null
                    ? Image.asset(
                        post.avatar.assetPath!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                      )
                    : Text(
                        post.avatar.symbol,
                        style: const TextStyle(fontSize: 64),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            post.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.65, color: muted),
          ),
          TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (context) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SectionTitle(post.title),
                    const SizedBox(height: 12),
                    Text(post.author),
                    const SizedBox(height: 16),
                    Text(post.body, style: const TextStyle(height: 1.6)),
                    if (post.price != null) ...[
                      const SizedBox(height: 16),
                      Text('Үнэ: ${post.price}'),
                    ],
                  ],
                ),
              ),
            ),
            child: const Text('Дэлгэрэнгүй'),
          ),
          const SizedBox(height: 10),
          Text(
            post.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (post.price != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Үнэ: ${post.price}',
                    style: TextStyle(
                      fontSize: 14,
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Text(post.time, style: TextStyle(fontSize: 11, color: muted)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: post.liked ? 'Таалагдсаныг болих' : 'Таалагдлаа',
                    onPressed: onLike,
                    icon: Icon(
                      post.liked ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: post.liked ? const Color(0xFFDA4F89) : muted,
                    ),
                  ),
                  Text(
                    '${post.likes}',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  TextButton.icon(
                    onPressed: onComments,
                    style: TextButton.styleFrom(foregroundColor: muted),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: Text('${post.comments.length}'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showPostImage(BuildContext context, Post post) =>
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF151020),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  key: const ValueKey('post-image-viewer'),
                  minScale: .8,
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(
                      post.imageBytes!,
                      fit: BoxFit.contain,
                      semanticLabel: post.title,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton.filledTonal(
                  tooltip: 'Зургийг хаах',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );

class _PostComposer extends StatefulWidget {
  const _PostComposer({this.pickImage});
  final Future<XFile?> Function()? pickImage;
  @override
  State<_PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<_PostComposer> {
  static const _maxImageBytes = 8 * 1024 * 1024;
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final body = TextEditingController();
  final price = TextEditingController();
  PostCategory category = PostCategory.sale;
  PostAvatar avatar = PostAvatar.books;
  Uint8List? imageBytes;
  String? imageName;
  String? imageError;
  bool pickingImage = false;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> attachImage() async {
    if (pickingImage) return;
    setState(() {
      pickingImage = true;
      imageError = null;
    });
    try {
      final file =
          await (widget.pickImage?.call() ??
              ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 1600,
                imageQuality: 85,
                requestFullMetadata: false,
              ));
      if (file == null || !mounted) return;
      if (await file.length() > _maxImageBytes) {
        if (mounted) {
          setState(
            () => imageError = '8 MB-аас бага хэмжээтэй зураг сонгоно уу.',
          );
        }
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > _maxImageBytes) {
        setState(
          () => imageError = '8 MB-аас бага хэмжээтэй зураг сонгоно уу.',
        );
        return;
      }
      // Validate the selected file before storing or publishing it.
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1600,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      if (!mounted) return;
      setState(() {
        imageBytes = bytes;
        imageName = file.name;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      final denied = RegExp(
        'permission|denied|access',
        caseSensitive: false,
      ).hasMatch(error.code);
      setState(
        () => imageError = denied
            ? 'Зурагт хандах зөвшөөрөл хэрэгтэй. Төхөөрөмжийн тохиргооноос зөвшөөрнө үү.'
            : 'Зураг сонгох боломжгүй байна. Дахин оролдоно уу.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => imageError =
              'Зургийг уншиж чадсангүй. JPG, PNG зэрэг зураг сонгоно уу.',
        );
      }
    } finally {
      if (mounted) setState(() => pickingImage = false);
    }
  }

  void publish() {
    if (pickingImage || !formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Post(
        author: 'Гүндэгмаа • 2-р курс',
        subtitle: 'Software Engineering',
        title: title.text.trim(),
        body: body.text.trim(),
        category: category,
        price:
            (category == PostCategory.sale ||
                    category == PostCategory.rental) &&
                price.text.trim().isNotEmpty
            ? '${price.text.trim()}₮'
            : null,
        imageBytes: imageBytes,
        avatar: avatar,
        imageName: imageName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      22,
      0,
      22,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Шинэ нийтлэл'),
            const SizedBox(height: 6),
            Text(
              'Хэрэгтэй зүйлээ хүрээлэлтэйгээ хуваалцаарай.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<PostCategory>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Төрөл'),
              items:
                  [
                        PostCategory.sale,
                        PostCategory.exchange,
                        PostCategory.rental,
                        PostCategory.question,
                      ]
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                      )
                      .toList(),
              onChanged: pickingImage
                  ? null
                  : (value) => setState(() => category = value!),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: title,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Гарчиг'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Гарчиг оруулна уу'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: body,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Тайлбар'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Тайлбар оруулна уу'
                  : null,
            ),
            if (category == PostCategory.sale ||
                category == PostCategory.rental) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Үнэ (заавал биш)',
                  suffixText: '₮',
                ),
                validator: (value) =>
                    value != null &&
                        value.trim().isNotEmpty &&
                        (int.tryParse(value.trim()) == null ||
                            int.parse(value.trim()) < 0)
                    ? 'Үнийг эерэг бүхэл тоогоор оруулна уу'
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            if (imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(
                  imageBytes!,
                  key: const ValueKey('post-image-preview'),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  semanticLabel: 'Сонгосон зургийн урьдчилсан харагдац',
                ),
              ),
              const SizedBox(height: 7),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('pick-post-image'),
                    onPressed: pickingImage ? null : attachImage,
                    icon: pickingImage
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 21,
                          ),
                    label: Text(
                      pickingImage
                          ? 'Зураг уншиж байна…'
                          : imageBytes == null
                          ? 'Зураг нэмэх'
                          : 'Зураг солих',
                    ),
                  ),
                ),
                if (imageBytes != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    key: const ValueKey('remove-post-image'),
                    tooltip: 'Зургийг хасах',
                    onPressed: pickingImage
                        ? null
                        : () => setState(() {
                            imageBytes = null;
                            imageName = null;
                            imageError = null;
                          }),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Өөрийн зураг · 8 MB хүртэл. Зураггүй бол дүрс сонгоорой.',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (imageError != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  imageError!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
            if (imageBytes == null) ...[
              const SizedBox(height: 14),
              const Text(
                'Зарын дүрс / аватар',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in PostAvatar.values)
                    ChoiceChip(
                      key: ValueKey('avatar-${option.name}'),
                      avatar: option.assetPath != null
                          ? Image.asset(
                              option.assetPath!,
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                            )
                          : Text(option.symbol),
                      label: Text(option.label),
                      selected: avatar == option,
                      onSelected: pickingImage
                          ? null
                          : (_) => setState(() => avatar = option),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: pickingImage ? null : publish,
              icon: const Icon(Icons.arrow_upward_rounded, size: 19),
              label: const Text('Нийтлэх'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post});
  final Post post;
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void send() {
    if (controller.text.trim().isEmpty) return;
    setState(() {
      widget.post.comments.add('Гүндэгмаа: ${controller.text.trim()}');
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      0,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .48,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Сэтгэгдлүүд'),
          const SizedBox(height: 12),
          Expanded(
            child: widget.post.comments.isEmpty
                ? const Center(child: Text('Эхний сэтгэгдлийг бичээрэй'))
                : ListView(
                    children: widget.post.comments
                        .map(
                          (c) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withValues(alpha: .07),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(c, style: const TextStyle(height: 1.5)),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Сэтгэгдэл бичих',
                    counterText: '',
                  ),
                  onSubmitted: (_) => send(),
                ),
              ),
              IconButton(
                tooltip: 'Илгээх',
                onPressed: send,
                icon: const Icon(Icons.send_rounded, color: AppColors.purple),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
