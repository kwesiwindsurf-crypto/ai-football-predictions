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

class _LiveMatchesCarouselState extends State<LiveMatchesCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _activePage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.liveMatches.isEmpty) return const SizedBox.shrink();

    final primary = AppTheme.primaryOf(context);
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
                          color: _activePage > 0 ? Colors.white : Colors.white24,
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
                          color: _activePage < widget.liveMatches.length - 1 ? Colors.white : Colors.white24,
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
          height: 154,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.liveMatches.length,
            onPageChanged: (idx) => setState(() => _activePage = idx),
            itemBuilder: (context, index) {
              final match = widget.liveMatches[index];
              return _buildCarouselCard(match, surface, borderColor, primary);
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
    Color primary,
  ) {
    final homeScore = match.homeScore ?? 0;
    final awayScore = match.awayScore ?? 0;
    final elapsed = DateTime.now().difference(match.date.toLocal()).inMinutes;
    final minuteStr = match.statusShort != null && match.statusShort!.isNotEmpty && match.statusShort != 'LIVE'
        ? match.statusShort!
        : "${elapsed > 0 && elapsed <= 120 ? elapsed : 80}'";

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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top: League Name + Live Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "$minuteStr LIVE",
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

            const SizedBox(height: 10),

            // Middle: Teams & Scores
            Row(
              children: [
                // Home Team
                Expanded(
                  child: Row(
                    children: [
                      _buildTeamLogo(match.homeLogo, match.homeTeam),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          match.homeTeam,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Live Scoreboard
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF374151)),
                  ),
                  child: Text(
                    "$homeScore - $awayScore",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: Colors.white,
                      letterSpacing: 1.0,
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
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildTeamLogo(match.awayLogo, match.awayTeam),
                    ],
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Bottom: AI Recommendation Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'AI PICK',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      match.prediction.recommendation,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ],
              ),
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
