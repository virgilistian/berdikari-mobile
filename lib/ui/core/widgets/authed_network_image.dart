import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/services/api_client.dart';

/// Renders a network image served behind `auth:sanctum` (product photo, and
/// any future per-entity image) by attaching the current bearer token as a
/// request header. Falls back to [placeholder] while the headers/image are
/// loading or if either fails — a missing/unreachable photo never breaks
/// the surrounding layout.
class AuthedNetworkImage extends StatelessWidget {
  const AuthedNetworkImage({
    super.key,
    required this.url,
    required this.placeholder,
    this.fit = BoxFit.cover,
  });

  final String url;
  final Widget placeholder;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final apiClient = context.read<ApiClient>();
    return FutureBuilder<Map<String, String>>(
      future: apiClient.authHeaders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return placeholder;
        return Image.network(
          url,
          headers: snapshot.data,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => placeholder,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : placeholder,
        );
      },
    );
  }
}
