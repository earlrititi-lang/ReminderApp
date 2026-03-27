
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/reminder.dart';

class ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleComplete;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onTap,
    required this.onDelete,
    required this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = _safeDateFormat('dd MMM yyyy', 'es_ES');
    final timeFormat = DateFormat('HH:mm');
    final isOverdue =
        reminder.dateTime.isBefore(DateTime.now()) && !reminder.isCompleted;
    final isCompleted = reminder.isCompleted;
    final borderColor = isCompleted
        ? AppColors.success
        : (isOverdue ? AppColors.accent : AppColors.panelStroke);
    final glowColor = isCompleted ? AppColors.success : AppColors.accent;
    final titleColor = isCompleted ? AppColors.success : AppColors.textPrimary;
    final secondaryColor =
        isCompleted ? AppColors.success : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Slidable(
        key: ValueKey(reminder.id),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          dismissible: DismissiblePane(
            onDismissed: () => onDelete(),
          ),
          children: [
            CustomSlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: Colors.transparent,
              child: const _SwipeDeleteBackground(),
            ),
          ],
        ),
        child: Builder(
          builder: (context) {
            final animation = Slidable.of(context)?.animation;
            return AnimatedBuilder(
              animation: animation ?? const AlwaysStoppedAnimation(0.0),
              builder: (context, child) {
                final progress = (animation?.value ?? 0.0).clamp(0.0, 1.0);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      child!,
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SwipeOverlayPainter(progress),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(16),
                  splashColor: AppColors.accentSoft,
                  highlightColor: AppColors.accentSoft.withValues(alpha: 0.2),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: isCompleted ? 0.6 : 1.0,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 250),
                      scale: isCompleted ? 0.98 : 1.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.panelTop,
                              AppColors.panelBottom,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: glowColor.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color:
                                  AppColors.panelStroke.withValues(alpha: 0.6),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Icono de completado (circular)
                              GestureDetector(
                                onTap: onToggleComplete,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isCompleted
                                          ? AppColors.success
                                          : (isOverdue
                                              ? AppColors.accent
                                              : AppColors.textMuted),
                                      width: 3,
                                    ),
                                    color: isCompleted
                                        ? AppColors.success
                                        : Colors.transparent,
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder: (child, animation) =>
                                        ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                    child: isCompleted
                                        ? const Icon(
                                            Icons.check,
                                            key: ValueKey('check'),
                                            color: Colors.white,
                                            size: 24,
                                          )
                                        : const SizedBox(
                                            key: ValueKey('empty'),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Contenido
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnimatedDefaultTextStyle(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      curve: Curves.easeOutCubic,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: titleColor,
                                        decoration: isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationThickness: 2,
                                        decorationColor: AppColors.success,
                                      ),
                                      child: Text(reminder.title),
                                    ),
                                    if (reminder.description != null &&
                                        reminder.description!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      AnimatedDefaultTextStyle(
                                        duration:
                                            const Duration(milliseconds: 250),
                                        curve: Curves.easeOutCubic,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: secondaryColor,
                                          decoration: isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          decorationThickness: 2,
                                          decorationColor: AppColors.success,
                                        ),
                                        child: Text(
                                          reminder.description!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Fecha y hora
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? AppColors.success
                                              .withValues(alpha: 0.2)
                                          : (isOverdue
                                              ? AppColors.danger
                                                  .withValues(alpha: 0.15)
                                              : AppColors.panelInset
                                                  .withValues(alpha: 0.6)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      dateFormat.format(reminder.dateTime),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isCompleted
                                            ? AppColors.success
                                            : (isOverdue
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: isCompleted
                                            ? AppColors.success
                                            : (isOverdue
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeFormat.format(reminder.dateTime),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isCompleted
                                              ? AppColors.success
                                              : (isOverdue
                                                  ? AppColors.textPrimary
                                                  : AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  DateFormat _safeDateFormat(String pattern, String locale) {
    try {
      return DateFormat(pattern, locale);
    } catch (_) {
      return DateFormat(pattern);
    }
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}

class _SwipeOverlayPainter extends CustomPainter {
  final double progress;
  const _SwipeOverlayPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final eased = Curves.easeOutCubic.transform(progress);
    final redWidth = size.width * eased;
    final redLeft = size.width - redWidth;
    final redRect = Rect.fromLTWH(redLeft, 0, redWidth, size.height);

    final redPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0x00FF3B30),
          Color(0x55FF3B30),
          Color(0x99FF3B30),
          Color(0xCCFF3B30),
          Color(0xFFFF3B30),
        ],
        stops: [
          0.0,
          0.35,
          0.6,
          0.82,
          1.0,
        ],
      ).createShader(redRect);
    canvas.drawRect(redRect, redPaint);
  }

  @override
  bool shouldRepaint(covariant _SwipeOverlayPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
