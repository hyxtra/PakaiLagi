import 'package:flutter/material.dart';

import '../models/cloud_pickup_request.dart';
import '../models/item.dart';
import '../theme/app_palette.dart';

/// Status tiap langkah pada timeline transaksi.
enum StepProgressState { done, active, upcoming, rejected }

@immutable
class TransactionStep {
  const TransactionStep({
    required this.shortLabel,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.state,
    this.timestamp,
  });

  final String shortLabel;
  final String title;
  final String subtitle;
  final IconData icon;
  final StepProgressState state;
  final DateTime? timestamp;
}

/// Membangun langkah-langkah progress transaksi seperti e-commerce
/// (Diajukan -> Disetujui -> Serah Terima -> Selesai), baik dari sudut
/// pandang peminta maupun pemberi barang.
List<TransactionStep> buildTransactionSteps({
  required ItemStatus itemStatus,
  required CloudPickupRequest? request,
  required bool isOwner,
}) {
  if (request != null && request.status == 'rejected') {
    return [
      TransactionStep(
        shortLabel: 'Diajukan',
        title: 'Pengajuan Dikirim',
        subtitle: 'Metode: ${request.method}',
        icon: Icons.send_rounded,
        state: StepProgressState.done,
        timestamp: request.createdAt,
      ),
      TransactionStep(
        shortLabel: 'Ditolak',
        title: 'Pengajuan Ditolak',
        subtitle: 'Pengajuan tidak disetujui atau barang diberikan ke peminta lain.',
        icon: Icons.cancel_outlined,
        state: StepProgressState.rejected,
        timestamp: request.decidedAt,
      ),
    ];
  }

  final reqAccepted = request?.status == 'accepted';
  final isCompleted = itemStatus == ItemStatus.completed;
  final isReserved = itemStatus == ItemStatus.reserved;

  // Langkah 1: Pengajuan / Penawaran
  final hasRequest = request != null;
  final step1Done = hasRequest || isReserved || isCompleted;

  // Langkah 2: Persetujuan
  final step2Done = reqAccepted || isReserved || isCompleted;
  final step2Active = !step2Done && (hasRequest || itemStatus == ItemStatus.available);

  // Langkah 3: Serah Terima
  final step3Done = isCompleted;
  final step3Active = !step3Done && (isReserved || reqAccepted);

  // Langkah 4: Selesai
  final step4Done = isCompleted;

  final methodSuffix =
      request != null && request.method.isNotEmpty ? ' (${request.method})' : '';
  final peerLabel = request?.requesterName ?? 'peminta';

  return [
    TransactionStep(
      shortLabel: 'Diajukan',
      title: isOwner ? 'Barang & Pengajuan' : 'Pengajuan Dikirim',
      subtitle: isOwner
          ? (hasRequest
              ? 'Dipilih untuk $peerLabel$methodSuffix'
              : 'Barang tayang dan menunggu peminta.')
          : 'Pengajuan terkirim$methodSuffix.',
      icon: Icons.assignment_turned_in_outlined,
      state: step1Done ? StepProgressState.done : StepProgressState.active,
      timestamp: request?.createdAt,
    ),
    TransactionStep(
      shortLabel: 'Disetujui',
      title: 'Disetujui Pemberi',
      subtitle: step2Done
          ? (isOwner
              ? 'Kamu menyetujui $peerLabel$methodSuffix.'
              : 'Pengajuan disetujui! Alamat lengkap telah dibuka.')
          : (isOwner
              ? 'Tinjau pengajuan masuk di Kelola Pengajuan.'
              : 'Menunggu pemberi meninjau pengajuanmu.'),
      icon: Icons.verified_outlined,
      state: step2Done
          ? StepProgressState.done
          : (step2Active ? StepProgressState.active : StepProgressState.upcoming),
      timestamp: step2Done ? request?.decidedAt : null,
    ),
    TransactionStep(
      shortLabel: 'Serah Terima',
      title: 'Proses Serah Terima',
      subtitle: step3Done
          ? 'Barang telah diserahterimakan.'
          : step3Active
              ? (isOwner
                  ? 'Koordinasikan pengambilan dengan $peerLabel via Chat, lalu tandai selesai.'
                  : 'Silakan koordinasi pengambilan via Chat atau buka titik Maps.')
              : 'Menunggu persetujuan sebelum serah terima.',
      icon: Icons.handshake_outlined,
      state: step3Done
          ? StepProgressState.done
          : (step3Active ? StepProgressState.active : StepProgressState.upcoming),
    ),
    TransactionStep(
      shortLabel: 'Selesai',
      title: 'Transaksi Selesai',
      subtitle: step4Done
          ? 'Barang diterima & transaksi dinyatakan selesai.'
          : 'Menunggu konfirmasi serah terima selesai.',
      icon: Icons.task_alt_rounded,
      state: step4Done ? StepProgressState.done : StepProgressState.upcoming,
      timestamp: step4Done ? null : null, // Diisi oleh caller bila ada updatedAt
    ),
  ];
}

/// Versi helper yang ikut menyertakan waktu selesai (`completedAt`).
List<TransactionStep> buildTransactionStepsWithDates({
  required ItemStatus itemStatus,
  required CloudPickupRequest? request,
  required bool isOwner,
  DateTime? itemCreatedAt,
  DateTime? completedAt,
}) {
  final base = buildTransactionSteps(
    itemStatus: itemStatus,
    request: request,
    isOwner: isOwner,
  );
  if (base.length < 4) return base;
  return [
    TransactionStep(
      shortLabel: base[0].shortLabel,
      title: base[0].title,
      subtitle: base[0].subtitle,
      icon: base[0].icon,
      state: base[0].state,
      timestamp: base[0].timestamp ?? itemCreatedAt,
    ),
    base[1],
    base[2],
    TransactionStep(
      shortLabel: base[3].shortLabel,
      title: base[3].title,
      subtitle: base[3].subtitle,
      icon: base[3].icon,
      state: base[3].state,
      timestamp: base[3].state == StepProgressState.done ? completedAt : null,
    ),
  ];
}

/// Format tanggal singkat berbahasa Indonesia: `27 Nov, 05:30`.
String formatTransactionTimestamp(DateTime? dt) {
  if (dt == null) return '';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final m = months[(dt.month - 1).clamp(0, 11)];
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} $m, $hh:$mm';
}

/// Progress bar horizontal ringkas ala Shopee/Tokopedia untuk kartu Aktivitas.
class TransactionProgressBar extends StatelessWidget {
  const TransactionProgressBar({
    super.key,
    required this.steps,
  });

  final List<TransactionStep> steps;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final activeStep = _currentHighlightedStep(steps);
    final isRejected = steps.any((s) => s.state == StepProgressState.rejected);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris node + garis penghubung
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                _StepNode(step: steps[i]),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2.5,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: _connectorColor(steps[i], steps[i + 1], p),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Label singkat sejajar node
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final s in steps)
                Flexible(
                  child: Text(
                    s.shortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: s.state == StepProgressState.active ||
                              s.state == StepProgressState.rejected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: switch (s.state) {
                        StepProgressState.done => p.primary,
                        StepProgressState.active => p.accentText,
                        StepProgressState.rejected => p.danger,
                        StepProgressState.upcoming => p.textMuted,
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Banner status langkah saat ini
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isRejected
                  ? p.danger.withValues(alpha: 0.1)
                  : activeStep.state == StepProgressState.done
                      ? p.primary.withValues(alpha: 0.1)
                      : p.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  activeStep.icon,
                  size: 16,
                  color: isRejected
                      ? p.danger
                      : activeStep.state == StepProgressState.done
                          ? p.primary
                          : p.accentText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeStep.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isRejected ? p.danger : p.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeStep.subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: p.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TransactionStep _currentHighlightedStep(List<TransactionStep> steps) {
    for (final s in steps) {
      if (s.state == StepProgressState.rejected ||
          s.state == StepProgressState.active) {
        return s;
      }
    }
    return steps.last;
  }

  Color _connectorColor(
      TransactionStep left, TransactionStep right, AppPalette p) {
    if (right.state == StepProgressState.rejected) return p.danger;
    if (left.state == StepProgressState.done &&
        (right.state == StepProgressState.done ||
            right.state == StepProgressState.active)) {
      return p.primary;
    }
    return p.border;
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({required this.step});
  final TransactionStep step;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (Color bg, Color fg, IconData icon) = switch (step.state) {
      StepProgressState.done => (p.primary, p.onPrimary, Icons.check),
      StepProgressState.active => (p.accent, p.onAccent, step.icon),
      StepProgressState.rejected => (p.danger, p.onDanger, Icons.close),
      StepProgressState.upcoming => (p.surface, p.textMuted, step.icon),
    };
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: step.state == StepProgressState.upcoming
            ? Border.all(color: p.border, width: 1.5)
            : null,
      ),
      child: Icon(icon, size: 13, color: fg),
    );
  }
}

/// Timeline vertikal lengkap dengan stempel waktu (untuk Detail Barang / sheet).
class TransactionProgressTimeline extends StatelessWidget {
  const TransactionProgressTimeline({
    super.key,
    required this.steps,
    this.heading = 'Progress Transaksi',
  });

  final List<TransactionStep> steps;
  final String heading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              heading,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: p.text,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              step: steps[i],
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.isLast});
  final TransactionStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final timeStr = formatTransactionTimestamp(step.timestamp);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _StepNode(step: step),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: step.state == StepProgressState.done
                        ? p.primary
                        : p.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: step.state == StepProgressState.upcoming
                                ? FontWeight.w600
                                : FontWeight.w800,
                            color: step.state == StepProgressState.rejected
                                ? p.danger
                                : step.state == StepProgressState.upcoming
                                    ? p.textMuted
                                    : p.text,
                          ),
                        ),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: p.textMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

