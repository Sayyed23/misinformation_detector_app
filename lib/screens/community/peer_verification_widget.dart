import 'package:flutter/material.dart';

class PeerVerificationWidget extends StatefulWidget {
  final int initialUpvotes;
  final int initialDownvotes;

  const PeerVerificationWidget({
    super.key,
    this.initialUpvotes = 0,
    this.initialDownvotes = 0,
  });

  @override
  State<PeerVerificationWidget> createState() => _PeerVerificationWidgetState();
}

class _PeerVerificationWidgetState extends State<PeerVerificationWidget> {
  late int _upvotes;
  late int _downvotes;

  @override
  void initState() {
    super.initState();
    _upvotes = widget.initialUpvotes;
    _downvotes = widget.initialDownvotes;
  }

  void _upvote() {
    setState(() {
      _upvotes++;
    });
  }

  void _downvote() {
    setState(() {
      _downvotes++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.thumb_up),
          onPressed: _upvote,
        ),
        Text('$_upvotes'),
        IconButton(
          icon: const Icon(Icons.thumb_down),
          onPressed: _downvote,
        ),
        Text('$_downvotes'),
      ],
    );
  }
}
