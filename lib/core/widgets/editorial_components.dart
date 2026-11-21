import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/content/data/content_models.dart';
import '../../features/content/presentation/post_actions_bar.dart';
import '../theme/side_b_theme.dart';
import '../layout/side_b_layout.dart';
import 'olive_shimmer.dart';
import '../utils/text_formatters.dart';

class EditorialHeader extends StatelessWidget {
  const EditorialHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
    this.subtitle,
    this.trailing,
  });
  final String eyebrow;
  final String title;
  final String? description;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: SideBLayout.maxContentWidth,
          ),
          child: Padding(
            padding: SideBLayout.pageInsets(
              constraints.maxWidth,
              top: 24,
              bottom: 22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: title,
                          children: [
                            if (subtitle != null)
                              TextSpan(
                                text: '\n$subtitle',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    if (trailing case final action?) ...[
                      const SizedBox(width: 12),
                      action,
                    ],
                  ],
                ),
                if (description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class NetworkCover extends StatelessWidget {
  const NetworkCover({
    super.key,
    this.url,
    required this.aspectRatio,
    this.height,
    this.child,
    this.fit = BoxFit.cover,
    this.backgroundColor,
  });
  final BoxFit fit;
  final Color? backgroundColor;
  final String? url;
  final double aspectRatio;
  final double? height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color:
                backgroundColor ??
                Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
          if (url != null)
            Image.network(
              url!,
              fit: fit,
              frameBuilder: (context, image, frame, synchronous) =>
                  synchronous || frame != null
                  ? image
                  : const OliveShimmer(child: SkeletonBlock()),
              errorBuilder: (_, _, _) => const _CoverPlaceholder(),
            ),
          if (url == null) const _CoverPlaceholder(),
          if (child != null) child!,
        ],
      ),
    );
    if (height != null) return SizedBox(height: height, child: cover);
    return AspectRatio(aspectRatio: aspectRatio, child: cover);
  }
}

class FeaturedPostCard extends StatelessWidget {
  const FeaturedPostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.height,
    this.onComment,
  });
  final VoidCallback? onComment;
  final Post post;
  final VoidCallback onTap;
  final double? height;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: post.title,
    child: Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NetworkCover(url: post.image, aspectRatio: 1.55, height: height),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _tag(post).toUpperCase(),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                        ),
                      ),
                      const Icon(
                        LucideIcons.arrowUpRight,
                        size: 18,
                        color: SideBColors.olive,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    post.title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (post.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      post.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    _meta(post),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 6),
                  PostActionsBar(post: post, onComment: onComment ?? onTap),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: Center(
      child: Icon(
        LucideIcons.image,
        size: 28,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class CompactPostCard extends StatelessWidget {
  const CompactPostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.onComment,
  });
  final Post post;
  final VoidCallback onTap;
  final VoidCallback? onComment;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: post.title,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 84,
                  child: NetworkCover(url: post.image, aspectRatio: 1),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tag(post).toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      _PostMetadata(post: post),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 23),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            PostActionsBar(post: post, onComment: onComment ?? onTap),
          ],
        ),
      ),
    ),
  );
}

class EditorialPostCard extends StatelessWidget {
  const EditorialPostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.onComment,
  });
  final VoidCallback? onComment;
  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: post.title,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NetworkCover(url: post.image, aspectRatio: 1.35),
            const SizedBox(height: 13),
            Text(
              _tag(post).toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(height: 7),
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 9),
            Text(
              post.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            _PostMetadata(post: post),
            const SizedBox(height: 6),
            PostActionsBar(post: post, onComment: onComment ?? onTap),
          ],
        ),
      ),
    ),
  );
}

String _tag(Post post) => post.author ?? 'Editorial';

class _PostMetadata extends StatelessWidget {
  const _PostMetadata({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) =>
      Text(_meta(post), style: Theme.of(context).textTheme.labelMedium);
}

class PostCommentCount extends StatelessWidget {
  const PostCommentCount({super.key, required this.count, this.color});
  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count ${count == 1 ? 'comentario' : 'comentarios'}',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.chat_bubble_outline_rounded, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          '$count',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: color),
        ),
      ],
    ),
  );
}

String _meta(Post post) => [
  if (post.author != null) 'Por ${post.author}',
  if (post.date != null) formatSpanishDate(post.date),
].where((value) => value.isNotEmpty).join(' · ');
