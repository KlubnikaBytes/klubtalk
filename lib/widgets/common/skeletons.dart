import 'package:flutter/material.dart';

class Skeleton extends StatefulWidget {
  final double? height;
  final double? width;
  final double radius;

  const Skeleton({super.key, this.height, this.width, this.radius = 16});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.grey[300],
      end: Colors.grey[100],
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 15,
      itemBuilder: (context, index) => const ListTile(
        leading: Skeleton(height: 50, width: 50, radius: 25),
        title: Align(
            alignment: Alignment.centerLeft,
            child: Skeleton(height: 16, width: 150, radius: 4)),
        subtitle: Align(
            alignment: Alignment.centerLeft,
            child: Skeleton(height: 12, width: 250, radius: 4)),
      ),
    );
  }
}

class ContactListSkeleton extends StatelessWidget {
  const ContactListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 15,
      itemBuilder: (context, index) => const ListTile(
        leading: Skeleton(height: 40, width: 40, radius: 20),
        title: Align(
            alignment: Alignment.centerLeft,
            child: Skeleton(height: 16, width: 120, radius: 4)),
      ),
    );
  }
}

class ChatScreenSkeleton extends StatelessWidget {
  const ChatScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      itemCount: 15,
      itemBuilder: (context, index) {
        final isMe = index % 2 == 0;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Skeleton(
            height: 40,
            width: (index % 3 + 1) * 60.0, // Randomish width
            radius: 12,
          ),
        );
      },
    );
  }
}

class StatusListSkeleton extends StatelessWidget {
  const StatusListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 12,
      itemBuilder: (context, index) => const ListTile(
        leading: Skeleton(height: 52, width: 52, radius: 26),
        title: Align(
            alignment: Alignment.centerLeft,
            child: Skeleton(height: 16, width: 140, radius: 4)),
        subtitle: Align(
            alignment: Alignment.centerLeft,
            child: Skeleton(height: 12, width: 100, radius: 4)),
      ),
    );
  }
}

class CallLogSkeleton extends StatelessWidget {
  const CallLogSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 15,
      itemBuilder: (context, index) => ListTile(
        leading: const Skeleton(height: 40, width: 40, radius: 20),
        title: const Align(
            alignment: Alignment.centerLeft,
            child: Skeleton(height: 16, width: 130, radius: 4)),
        subtitle: const Align(
            alignment: Alignment.centerLeft,
            child: Skeleton(height: 12, width: 160, radius: 4)),
        trailing: Skeleton(
          height: 24,
          width: 24,
          radius: 12,
        ),
      ),
    );
  }
}

class SettingsSkeleton extends StatelessWidget {
  const SettingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) => const ListTile(
        leading: Skeleton(height: 24, width: 24, radius: 4),
        title: Align(
            alignment: Alignment.centerLeft,
            child: Skeleton(height: 16, width: 180, radius: 4)),
        subtitle: Align(
            alignment: Alignment.centerLeft,
            child: Skeleton(height: 12, width: 220, radius: 4)),
      ),
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Center(child: Skeleton(height: 100, width: 100, radius: 50)),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: List.generate(
              4,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Skeleton(height: 12, width: 80, radius: 4),
                    SizedBox(height: 8),
                    Skeleton(height: 48, width: double.infinity, radius: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
