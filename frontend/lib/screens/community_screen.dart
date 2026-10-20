import 'package:flutter/material.dart';

import '../models/post.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
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
      builder: (context) => const _PostComposer(),
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
      builder: (context) => _CommentsSheet(post: post),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = posts.where(
      (p) => filter == 0 || p.category == PostCategory.values[filter - 1],
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 12, 26, 100),
      children: [
        const Text(
          'Оюутнуудын орчин',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 22),
        SegmentTabs(
          labels: const ['Бүгд', 'Зар', 'Асуулт', 'Багш'],
          selected: filter,
          onSelected: (value) => setState(() => filter = value),
        ),
        const SizedBox(height: 24),
        for (final post in visible) ...[
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.author,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (post.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    post.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  post.title,
                  style: TextStyle(
                    fontSize: post.category == PostCategory.teacher ? 18 : 21,
                    height: 1.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (post.category != PostCategory.teacher) ...[
                  const SizedBox(height: 10),
                  Text(
                    post.body,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  children: [
                    Text(
                      post.price != null ? 'Үнэ: ${post.price}' : post.time,
                      style: TextStyle(
                        fontSize: post.price != null ? 16 : 12,
                        fontWeight: post.price != null
                            ? FontWeight.w800
                            : FontWeight.normal,
                        color: post.price != null
                            ? AppColors.blue
                            : AppColors.muted,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: post.liked
                              ? 'Таалагдсаныг болих'
                              : 'Таалагдлаа',
                          onPressed: () => setState(() {
                            post.liked = !post.liked;
                            post.likes += post.liked ? 1 : -1;
                          }),
                          icon: Icon(
                            post.liked ? Icons.favorite : Icons.favorite_border,
                            size: 19,
                            color: post.liked
                                ? AppColors.blue
                                : AppColors.muted,
                          ),
                        ),
                        Text(
                          '${post.likes}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        TextButton.icon(
                          onPressed: () => showComments(post),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.muted,
                          ),
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: Text('${post.comments.length}'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _PostComposer extends StatefulWidget {
  const _PostComposer();
  @override
  State<_PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<_PostComposer> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final body = TextEditingController();
  final price = TextEditingController();
  PostCategory category = PostCategory.sale;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
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
            const SizedBox(height: 20),
            DropdownButtonFormField<PostCategory>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Төрөл'),
              items: [PostCategory.sale, PostCategory.question]
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (value) => setState(() => category = value!),
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
            if (category == PostCategory.sale) ...[
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
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.pop(
                  context,
                  Post(
                    author: 'Гүндэгмаа • 2-р курс',
                    subtitle: 'Software Engineering',
                    title: title.text.trim(),
                    body: body.text.trim(),
                    category: category,
                    price:
                        category == PostCategory.sale &&
                            price.text.trim().isNotEmpty
                        ? '${price.text.trim()}₮'
                        : null,
                  ),
                );
              },
              child: const Text('Нийтлэх'),
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
    if (controller.text.trim().isEmpty) {
      return;
    }
    setState(() {
      widget.post.comments.add('Гүндэгмаа: ${controller.text.trim()}');
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
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
                          (c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(c),
                          ),
                        )
                        .toList(),
                  ),
          ),
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
                icon: const Icon(Icons.send, color: AppColors.blue),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
