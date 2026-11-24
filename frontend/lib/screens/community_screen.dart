import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post.dart';
import '../services/post_api.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    super.key,
    this.pickPostImage,
    this.postApi,
    this.userName = 'Гүндэгмаа',
    this.userCourse = 2,
    this.role = 'student',
  });

  /// Allows a host or a widget test to provide its own gallery picker.
  final Future<XFile?> Function()? pickPostImage;
  final PostApi? postApi;

  /// The signed-in student, used as the author of new posts and comments.
  final String userName;
  final int? userCourse;
  final String role;

  @override
  State<CommunityScreen> createState() => CommunityScreenState();
}

class CommunityScreenState extends State<CommunityScreen> {
  final posts = demoPosts();
  int filter = 0;

  String get _userLabel => widget.userCourse == null
      ? widget.userName
      : '${widget.userName} • ${widget.userCourse}-р курс';

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final api = widget.postApi;
    if (api == null) return;
    try {
      final remotePosts = await api.listPosts();
      if (mounted) {
        setState(() {
          posts
            ..clear()
            ..addAll(remotePosts);
        });
      }
    } on PostApiException {
      // Keep the demo feed available if the API cannot be reached.
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  bool get _staff => widget.role == 'teacher' || widget.role == 'admin';

  Future<void> createPost() => _composePost();

  Future<void> editPost(Post post) => _composePost(existing: post);

  Future<void> _composePost({Post? existing}) async {
    final result = await showModalBottomSheet<Post>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _PostComposer(
        pickImage: widget.pickPostImage,
        author: _userLabel,
        userCourse: widget.userCourse,
        initial: existing,
        canAnnounce: _staff,
      ),
    );
    if (result != null && mounted) {
      final api = widget.postApi;
      if (api != null) {
        _showMessage(existing == null ? 'Зарыг серверт хадгалж байна…' : 'Зарыг шинэчилж байна…');
        try {
          if (existing == null) {
            result.id = await api.createPost(result);
          } else {
            await api.updatePost(result);
          }
        } on PostApiException catch (error) {
          if (!mounted) return;
          _showMessage(error.message);
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        if (existing == null) {
          posts.insert(0, result);
        } else {
          final index = posts.indexWhere((post) => post.id == existing.id);
          if (index >= 0) posts[index] = result;
        }
        filter = 0;
      });
      _showMessage(existing == null ? 'Нийтлэл амжилттай нэмэгдлээ' : 'Нийтлэл шинэчлэгдлээ');
    }
  }

  Future<void> deletePost(Post post) async {
    final id = post.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Зарыг устгах уу?'),
        content: Text('“${post.title}” зарыг устгана.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Болих')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Устгах')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.postApi?.deletePost(id);
      if (!mounted) return;
      setState(() => posts.removeWhere((item) => item.id == id));
      _showMessage('Зар устгагдлаа.');
    } on PostApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> toggleLike(Post post) async {
    final api = widget.postApi;
    final id = post.id;
    if (api != null && id != null) {
      try {
        final state = await api.toggleLike(id);
        if (!mounted) return;
        setState(() {
          post.liked = state.liked;
          post.likes = state.count;
        });
      } on PostApiException catch (error) {
        if (mounted) _showMessage(error.message);
      }
      return;
    }
    setState(() {
      post.liked = !post.liked;
      post.likes += post.liked ? 1 : -1;
      if (post.liked) {
        post.likers.insert(0, _userLabel);
      } else {
        post.likers.remove(_userLabel);
      }
    });
  }

  Future<void> showLikers(Post post) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _LikersSheet(
      post: post,
      load: widget.postApi != null && post.id != null
          ? () => widget.postApi!.listLikers(post.id!)
          : null,
    ),
  );

  Future<void> showComments(Post post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) =>
          _CommentsSheet(post: post, userName: widget.userName),
    );
    if (mounted) setState(() {});
  }

  Future<void> showDetails(Post post) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, refresh) => _PostDetails(
        post: post,
        onLike: () async {
          await toggleLike(post);
          refresh(() {});
        },
        onLikers: () => showLikers(post),
        onComments: () async {
          await showComments(post);
          refresh(() {});
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final visible = posts
        .where(
          (p) =>
              (filter == 0 || p.category == PostCategory.values[filter - 1]) &&
              p.visibleTo(widget.userCourse),
        )
        .toList();
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
        _CommunityBanner(
          onCreate: createPost,
          postCount: posts.where((p) => p.visibleTo(widget.userCourse)).length,
        ),
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
                constraints.maxWidth >= 320 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.3
                ? 2
                : 1;
            // Every card has the same slots, so each row is laid out with
            // equal heights and all rows end up the same size.
            return Column(
              children: [
                for (var start = 0; start < visible.length; start += columns)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = start; i < start + columns; i++) ...[
                            if (i > start) const SizedBox(width: 12),
                            Expanded(
                              child: i < visible.length
                                  ? _PostCard(
                                      post: visible[i],
                                      onLike: () => toggleLike(visible[i]),
                                      onLikers: () => showLikers(visible[i]),
                                      onComments: () =>
                                          showComments(visible[i]),
                                      onDetails: () => showDetails(visible[i]),
                                      canManage: (_staff || visible[i].isMine) &&
                                          visible[i].id != null,
                                      onEdit: () => editPost(visible[i]),
                                      onDelete: () => deletePost(visible[i]),
                                    )
                                  : const SizedBox(),
                            ),
                          ],
                        ],
                      ),
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
  const _CommunityBanner({required this.onCreate, required this.postCount});
  final VoidCallback onCreate;
  final int postCount;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6B30DC), Color(0xFF8B4FEA), Color(0xFFB083F5)],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.purple.withValues(alpha: .22),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Stack(
      children: [
        // Soft shapes behind the content.
        Positioned(
          right: -50,
          top: -60,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .08),
            ),
          ),
        ),
        Positioned(
          left: -40,
          bottom: -70,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .09),
                width: 22,
              ),
            ),
          ),
        ),
        // What students share here: books, questions, ideas.
        const Positioned(
          right: 16,
          top: 18,
          child: ExcludeSemantics(
            child: SizedBox(
              width: 96,
              height: 104,
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _BannerTile(
                      symbol: '📚',
                      angle: .14,
                      color: Color(0xFFFFE3A8),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 26,
                    child: _BannerTile(
                      symbol: '💬',
                      angle: -.16,
                      color: Color(0xFFD9C8FF),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 0,
                    child: _BannerTile(
                      symbol: '💡',
                      angle: .06,
                      color: Color(0xFFC6F3E4),
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .18),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forum_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'COMMUNITY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Leaves room for the tiles on the right.
              const Padding(
                padding: EdgeInsets.only(right: 104),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Хуваалцъя.\nХолбогдъё.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.15,
                        letterSpacing: -.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Ном, шинэ санаа, хэрэгтэй зөвлөгөө — чиний оюутны хүрээлэл.',
                      style: TextStyle(
                        color: Color(0xFFF1E8FF),
                        height: 1.45,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: onCreate,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.purple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Хуваалцах'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$postCount нийтлэл',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A small tilted emoji tile used as banner decoration.
class _BannerTile extends StatelessWidget {
  const _BannerTile({
    required this.symbol,
    required this.angle,
    required this.color,
    this.size = 48,
  });
  final String symbol;
  final double angle;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * .32),
        border: Border.all(color: Colors.white.withValues(alpha: .6), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x553A1688), offset: Offset(3, 5)),
        ],
      ),
      child: Text(symbol, style: TextStyle(fontSize: size * .46)),
    ),
  );
}

Color _categoryAccent(BuildContext context, PostCategory category) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (category) {
    PostCategory.sale => dark ? AppColors.lavender : AppColors.purple,
    PostCategory.exchange => dark ? AppColors.mint : const Color(0xFF277F74),
    PostCategory.rental =>
      dark ? const Color(0xFFFFBA80) : const Color(0xFFA95310),
    PostCategory.question =>
      dark ? const Color(0xFFF299C4) : const Color(0xFFBE4B89),
    PostCategory.teacher => dark ? AppColors.mint : const Color(0xFF277F74),
  };
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});
  final PostCategory category;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryAccent(context, category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        category.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: accent,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// The post's own photo, or its avatar tile when it has none.
class _PostVisual extends StatelessWidget {
  const _PostVisual({required this.post, required this.height});
  final Post post;
  final double height;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryAccent(context, post.category);
    final avatar = Container(
      key: const ValueKey('post-avatar'),
      height: height,
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
                width: height * .55,
                height: height * .55,
                fit: BoxFit.contain,
              )
            : Text(
                post.avatar.symbol,
                style: TextStyle(fontSize: height * .42),
              ),
      ),
    );
    if (!post.hasImage) return avatar;
    return Semantics(
      button: true,
      label: '${post.title} зургийг томруулах',
      child: InkWell(
        key: const ValueKey('open-post-image'),
        onTap: () => _showPostImage(context, post),
        borderRadius: BorderRadius.circular(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: post.imageBytes != null
              ? Image.memory(
                  post.imageBytes!,
                  key: const ValueKey('post-image'),
                  width: double.infinity,
                  height: height,
                  fit: BoxFit.cover,
                  semanticLabel: post.title,
                  errorBuilder: (_, error, stackTrace) => SizedBox(
                    height: height,
                    child: const Center(
                      child: Text('Зураг харуулах боломжгүй байна'),
                    ),
                  ),
                )
              : Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  height: height,
                  fit: BoxFit.cover,
                  semanticLabel: post.title,
                  errorBuilder: (_, error, stackTrace) => avatar,
                ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onLikers,
    required this.onComments,
    required this.onDetails,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onLikers;
  final VoidCallback onComments;
  final VoidCallback onDetails;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryAccent(context, post.category);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final scale = MediaQuery.textScalerOf(context).scale;
    return SurfaceCard(
      padding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: _CategoryChip(category: post.category)),
              if (post.audienceCourses.isNotEmpty) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Зөвхөн ${audienceLabel(post.audienceCourses)}',
                  child: Icon(Icons.group_rounded, size: 16, color: muted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              _PostVisual(post: post, height: 112),
              if (post.price != null)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      post.price!,
                      style: TextStyle(
                        fontSize: 13,
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Fixed two-line slots keep every card the same height.
          SizedBox(
            height: scale(15 * 1.35 * 2),
            child: Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: scale(12 * 1.5 * 2),
            child: Text(
              post.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.5, color: muted),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            post.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            post.timeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: muted),
          ),
          if (canManage)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Зар засах',
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                ),
                IconButton(
                  tooltip: 'Зар устгах',
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                ),
              ],
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onDetails,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              child: const Text('Дэлгэрэнгүй'),
            ),
          ),
          _PostActions(
            post: post,
            onLike: onLike,
            onLikers: onLikers,
            onComments: onComments,
          ),
        ],
      ),
    );
  }
}

/// Like button, a tappable like count (opens who reacted) and comments.
class _PostActions extends StatelessWidget {
  const _PostActions({
    required this.post,
    required this.onLike,
    required this.onLikers,
    required this.onComments,
  });
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onLikers;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        IconButton(
          tooltip: post.liked ? 'Таалагдсаныг болих' : 'Таалагдлаа',
          onPressed: onLike,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            post.liked ? Icons.favorite : Icons.favorite_border,
            size: 20,
            color: post.liked ? const Color(0xFFDA4F89) : muted,
          ),
        ),
        Tooltip(
          message: 'Хэн таалагдсаныг харах',
          child: InkWell(
            key: const ValueKey('open-post-likers'),
            onTap: onLikers,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text(
                '${post.likes}',
                style: TextStyle(
                  fontSize: 12,
                  color: muted,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onComments,
          style: TextButton.styleFrom(
            foregroundColor: muted,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: Text('${post.comments.length}'),
        ),
      ],
    );
  }
}

class _PostDetails extends StatelessWidget {
  const _PostDetails({
    required this.post,
    required this.onLike,
    required this.onLikers,
    required this.onComments,
  });
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onLikers;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final accent = _categoryAccent(context, post.category);
    Widget fact(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: muted)),
          ),
        ],
      ),
    );
    return SingleChildScrollView(
      key: const ValueKey('post-details'),
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _CategoryChip(category: post.category),
          ),
          const SizedBox(height: 12),
          SectionTitle(post.title),
          const SizedBox(height: 14),
          _PostVisual(post: post, height: post.hasImage ? 200 : 120),
          if (post.price != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Үнэ: ${post.price}',
                style: TextStyle(
                  fontSize: 17,
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(post.body, style: const TextStyle(fontSize: 15, height: 1.6)),
          const SizedBox(height: 18),
          Divider(color: Theme.of(context).dividerColor, height: 1),
          const SizedBox(height: 14),
          fact(Icons.person_outline_rounded, post.author),
          fact(Icons.schedule_rounded, post.timeLabel),
          fact(
            Icons.group_outlined,
            'Харагдах хүрээ: ${audienceLabel(post.audienceCourses)}',
          ),
          _PostActions(
            post: post,
            onLike: onLike,
            onLikers: onLikers,
            onComments: onComments,
          ),
        ],
      ),
    );
  }
}

/// Lists who reacted to a post.
class _LikersSheet extends StatefulWidget {
  const _LikersSheet({required this.post, this.load});
  final Post post;

  /// Fetches the names from the backend; null uses the post's local list.
  final Future<List<String>> Function()? load;

  @override
  State<_LikersSheet> createState() => _LikersSheetState();
}

class _LikersSheetState extends State<_LikersSheet> {
  late Future<List<String>> _names = _fetch();

  Future<List<String>> _fetch() =>
      widget.load?.call() ?? Future.value(widget.post.likers);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .48,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Таалагдсан хүмүүс'),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _names,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${snapshot.error}', textAlign: TextAlign.center),
                        TextButton.icon(
                          onPressed: () => setState(() => _names = _fetch()),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Дахин оролдох'),
                        ),
                      ],
                    ),
                  );
                }
                final names = snapshot.data ?? const [];
                if (names.isEmpty) {
                  return const Center(
                    child: Text(
                      'Одоогоор хэн ч таалагдсан гэж дараагүй байна.',
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: names.length,
                  itemBuilder: (context, index) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.purple.withValues(alpha: .12),
                      child: const Icon(
                        Icons.favorite,
                        size: 18,
                        color: Color(0xFFDA4F89),
                      ),
                    ),
                    title: Text(names[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
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
                    child: post.imageBytes != null
                        ? Image.memory(
                            post.imageBytes!,
                            fit: BoxFit.contain,
                            semanticLabel: post.title,
                          )
                        : Image.network(
                            post.imageUrl!,
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

/// Groups digits with thousands separators as the price is typed.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text
        .replaceAll(RegExp(r'[^0-9]'), '')
        .replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final text = groupThousands(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _PostComposer extends StatefulWidget {
  const _PostComposer({
    this.pickImage,
    required this.author,
    this.userCourse,
    this.initial,
    this.canAnnounce = false,
  });
  final Future<XFile?> Function()? pickImage;
  final String author;
  final int? userCourse;
  final Post? initial;
  final bool canAnnounce;
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

  /// Courses that may see the post; empty means everyone.
  final Set<int> audience = {};
  Uint8List? imageBytes;
  String? imageName;
  String? imageError;
  bool pickingImage = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    title.text = initial.title;
    body.text = initial.body;
    price.text = initial.price?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    category = initial.category;
    avatar = initial.avatar;
    audience.addAll(initial.audienceCourses);
  }

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
        author: widget.author,
        subtitle: '',
        id: widget.initial?.id,
        isMine: widget.initial?.isMine ?? true,
        likes: widget.initial?.likes ?? 0,
        liked: widget.initial?.liked ?? false,
        createdAt: widget.initial?.createdAt ?? DateTime.now(),
        audienceCourses: audience.toList()..sort(),
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
        imageUrl: imageBytes == null ? widget.initial?.imageUrl : null,
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
                        if (widget.canAnnounce) PostCategory.teacher,
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
                inputFormatters: [_ThousandsFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Үнэ (заавал биш)',
                  hintText: '25,000',
                  suffixText: '₮',
                ),
                validator: (value) =>
                    value != null &&
                        value.trim().isNotEmpty &&
                        int.tryParse(value.replaceAll(',', '').trim()) == null
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
            const SizedBox(height: 18),
            const Text(
              'Хэнд харуулах вэ?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              audience.isEmpty
                  ? 'Бүх курсын оюутанд харагдана.'
                  : 'Зөвхөн ${audienceLabel(audience.toList()..sort())}-ын '
                        'оюутанд харагдана.',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const ValueKey('audience-all'),
                  label: const Text('Бүгд'),
                  selected: audience.isEmpty,
                  onSelected: (_) => setState(audience.clear),
                ),
                for (final course in postAudienceCourses)
                  FilterChip(
                    key: ValueKey('audience-$course'),
                    label: Text('$course-р курс'),
                    selected: audience.contains(course),
                    onSelected: (selected) => setState(
                      () => selected
                          ? audience.add(course)
                          : audience.remove(course),
                    ),
                  ),
              ],
            ),
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
  const _CommentsSheet({required this.post, required this.userName});
  final Post post;
  final String userName;
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
      widget.post.comments.add('${widget.userName}: ${controller.text.trim()}');
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
