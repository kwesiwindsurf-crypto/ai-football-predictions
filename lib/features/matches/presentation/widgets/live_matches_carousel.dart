import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/match_model.dart' as model;
import '../../../match_details/presentation/pages/match_details_screen.dart';

class LiveMatchesCarousel extends StatefulWidget {
  final List<model.Match> liveMatches;

  const LiveMatchesCarousel({super.key, required this.liveMatches});

  @override
  State<LiveMatchesCarousel> createState() => _LiveMatchesCarouselState();
}

class _LiveMatchesCarouselState extends State<LiveMatchesCarousel>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _activePage = 0;

  /// Slow breathing pulse shared by the LIVE dot and the minute chip.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.liveMatches.isEmpty) return const SizedBox.shrink();

    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'LIVE MATCHES NOW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: Color(0xFFEF4444),
                ),
              ),
              const Spacer(),
              if (widget.liveMatches.length > 1)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _activePage > 0
                          ? () => _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: _activePage > 0
                              ? AppTheme.textPrimaryOf(context)
                              : AppTheme.textSecondaryOf(context).withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    Text(
                      '${_activePage + 1}/${widget.liveMatches.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _activePage < widget.liveMatches.length - 1
                          ? () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: _activePage < widget.liveMatches.length - 1
                              ? AppTheme.textPrimaryOf(context)
                              : AppTheme.textSecondaryOf(context).withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Carousel Slider
        SizedBox(
          height: 136,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.liveMatches.length,
            onPageChanged: (idx) => setState(() => _activePage = idx),
            itemBuilder: (context, index) {
              final match = widget.liveMatches[index];
              return _buildCarouselCard(match, surface, borderColor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselCard(
    model.Match match,
    Color surface,
    Color borderColor,
  ) {
    final homeScore = match.homeScore ?? 0;
    final awayScore = match.awayScore ?? 0;

    // Real match clock: the synced elapsed minute wins, kickoff math is
    // only the fallback when the payload carries no elapsed value.
    final status = (match.statusShort ?? '').toUpperCase();
    final int minute;
    if (status == 'HT') {
      minute = 45;
    } else if (match.elapsed != null && match.elapsed! > 0) {
      minute = match.elapsed!.clamp(1, 90);
    } else {
      minute = DateTime.now()
          .difference(match.date.toLocal())
          .inMinutes
          .clamp(1, 90);
    }
    final minuteLabel = status == 'HT' ? 'HT' : "$minute'";
    final progress = (minute / 90).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailsScreen(match: match),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppTheme.isDark(context) ? 0.4 : 0.08,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top: League Name + pulsing Live Badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    match.league,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => Opacity(
                          opacity: 0.35 + 0.65 * _pulse.value,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$minuteLabel LIVE',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Score hero flanked by the two teams
            Row(
              children: [
                // Home Team
                Expanded(
                  child: Row(
                    children: [
                      _buildTeamLogo(match.homeLogo, match.homeTeam),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          match.homeTeam,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Big live score — rolls when a goal lands
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.55),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: RichText(
                      key: ValueKey<String>('$homeScore-$awayScore'),
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 1.2,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                        children: [
                          TextSpan(text: '$homeScore'),
                          const TextSpan(
                            text: ' – ',
                            style: TextStyle(color: Color(0xFFEF4444)),
                          ),
                          TextSpan(text: '$awayScore'),
                        ],
                      ),
                    ),
                  ),
                ),

                // Away Team
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          match.awayTeam,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 7),
                      _buildTeamLogo(match.awayLogo, match.awayTeam),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Heat-gradient minute bar with a chip riding the fill edge.
            _MinuteBar(
              progress: progress,
              minuteLabel: minuteLabel,
              pulse: _pulse,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamLogo(String logoUrl, String teamName) {
    if (logoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: logoUrl,
        width: 24,
        height: 24,
        errorWidget: (context, url, error) => _buildFallbackCrest(teamName),
        placeholder: (context, url) => const SizedBox(width: 24, height: 24),
      );
    }
    return _buildFallbackCrest(teamName);
  }

  Widget _buildFallbackCrest(String teamName) {
    final words = teamName.trim().split(RegExp(r'\s+'));
    String initials;
    if (words.length >= 2) {
      initials = '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (teamName.length >= 2) {
      initials = teamName.substring(0, 2).toUpperCase();
    } else {
      initials = teamName.toUpperCase();
    }

    final colors = [
      const [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
      const [Color(0xFF831843), Color(0xFFEC4899)],
      const [Color(0xFF065F46), Color(0xFF10B981)],
      const [Color(0xFF581C87), Color(0xFF8B5CF6)],
      const [Color(0xFF7C2D12), Color(0xFFF97316)],
      const [Color(0xFF134E4A), Color(0xFF14B8A6)],
      const [Color(0xFF1E293B), Color(0xFF475569)],
      const [Color(0xFF701A75), Color(0xFFD946EF)],
    ];
    final hash = teamName.codeUnits.fold(0, (acc, c) => acc + c);
    final pair = colors[hash % colors.length];

    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pair,
        ),
        boxShadow: [
          BoxShadow(
            color: pair[0].withValues(alpha: 0.3),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// MB3 minute bar: green → amber → red heat fill that eases to the new
/// minute, with a chip riding the fill edge. Every change (even one minute)
/// pops the chip and flashes its glow so the movement is unmistakable.
class _MinuteBar extends StatefulWidget {
  final double progress;
  final String minuteLabel;
  final Animation<double> pulse;

  const _MinuteBar({
    required this.progress,
    required this.minuteLabel,
    required this.pulse,
  });

  @override
  State<_MinuteBar> createState() => _MinuteBarState();
}

class _MinuteBarState extends State<_MinuteBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash;
  late final Animation<double> _pop;

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _pop = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.22)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.22, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 65,
      ),
    ]).animate(_flash);
  }

  @override
  void didUpdateWidget(covariant _MinuteBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackColor = AppTheme.isDark(context)
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);
    final labelStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 8.5,
      fontWeight: FontWeight.w700,
      color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.75),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const chipWidth = 34.0;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: widget.progress),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            final fillWidth = (value * width).clamp(0.0, width);
            final chipLeft =
                (fillWidth - chipWidth / 2).clamp(0.0, width - chipWidth);
            return SizedBox(
              height: 34,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Track
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 16,
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: trackColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  // Heat fill
                  Positioned(
                    left: 0,
                    top: 16,
                    width: fillWidth,
                    height: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF00D06C),
                            Color(0xFFF59E0B),
                            Color(0xFFEF4444),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Minute chip riding the fill edge
                  Positioned(
                    left: chipLeft,
                    top: 0,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([widget.pulse, _flash]),
                      builder: (context, _) {
                        final flashing =
                            _flash.status == AnimationStatus.forward ||
                                _flash.status == AnimationStatus.completed;
                        final flashFactor =
                            flashing ? (1 - _flash.value).clamp(0.0, 1.0) : 0.0;
                        return Transform.scale(
                          scale: _pop.value,
                          child: Container(
                            width: chipWidth,
                            alignment: Alignment.center,
                            padding:
                                const EdgeInsets.symmetric(vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEF4444).withValues(
                                    alpha: (0.25 +
                                            0.3 * widget.pulse.value +
                                            0.5 * flashFactor)
                                        .clamp(0.0, 1.0),
                                  ),
                                  blurRadius: 8 + 6 * flashFactor,
                                  spreadRadius: 1 + 2 * flashFactor,
                                ),
                              ],
                            ),
                            child: Text(
                              widget.minuteLabel,
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Range labels
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("0'", style: labelStyle),
                        Text("90'", style: labelStyle),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
