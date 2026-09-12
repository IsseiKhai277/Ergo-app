import 'dart:io';

void main() {
  final file = File('lib/screens/jobs/my_jobs_screen.dart');
  var content = file.readAsStringSync();

  // Fix _MetaChip
  content = content.replaceAll(
'''        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),''',
'''        Flexible(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),''');

  // Regex to replace OutlinedButton.icon and ElevatedButton.icon
  // We'll replace them manually using RegExp or just string replacements for the specific buttons.
  
  // Since there are 6 buttons, and they all follow a similar structure, let's use RegExp.
  // Actually, replacing them specifically by pattern is safer.

  // 1. Message Buttons (OutlinedButton.icon)
  content = content.replaceAll(
'''                        child: OutlinedButton.icon(
                          onPressed: widget.onMessageTap,
                          icon: const Icon(Icons.message_outlined, size: 15),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.isClient
                                  ? 'Message Worker'
                                  : 'Message Client',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: Size.zero,
                          ),
                        ),''',
'''                        child: OutlinedButton(
                          onPressed: widget.onMessageTap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: Size.zero,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.message_outlined, size: 15),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.isClient ? 'Message Worker' : 'Message Client',
                                  style: GoogleFonts.inter(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),''');

  // 2. Job Complete Button
  content = content.replaceAll(
'''                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JobCompletionScreen(job: job),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 15,
                            ),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Job Complete',
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: Size.zero,
                              elevation: 0,
                            ),
                          ),''',
'''                          child: ElevatedButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JobCompletionScreen(job: job),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: Size.zero,
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, size: 15),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Job Complete',
                                    style: GoogleFonts.inter(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),''');

  // 3. Start Job Button
  content = content.replaceAll(
'''                          child: ElevatedButton.icon(
                            onPressed: widget.onStartJob,
                            icon: const Icon(
                              Icons.directions_run_rounded,
                              size: 15,
                            ),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Start Job',
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.themeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: Size.zero,
                              elevation: 0,
                            ),
                          ),''',
'''                          child: ElevatedButton(
                            onPressed: widget.onStartJob,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.themeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: Size.zero,
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.directions_run_rounded, size: 15),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Start Job',
                                    style: GoogleFonts.inter(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),''');

  // 4. Accept Offer Button
  content = content.replaceAll(
'''                          child: ElevatedButton.icon(
                            onPressed: (_isAccepting || _isExpired)
                                ? null
                                : () => _handleAcceptOffer(context),
                            icon: _isAccepting
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _isExpired
                                        ? Icons.block_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 15,
                                  ),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _isAccepting
                                    ? 'Accepting...'
                                    : _isExpired
                                        ? 'Expired'
                                        : 'Accept Offer',
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isExpired
                                  ? AppColors.textHint
                                  : widget.themeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: Size.zero,
                              elevation: 0,
                            ),
                          ),''',
'''                          child: ElevatedButton(
                            onPressed: (_isAccepting || _isExpired)
                                ? null
                                : () => _handleAcceptOffer(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isExpired ? AppColors.textHint : widget.themeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: Size.zero,
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _isAccepting
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _isExpired
                                            ? Icons.block_rounded
                                            : Icons.check_circle_outline_rounded,
                                        size: 15,
                                      ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _isAccepting
                                        ? 'Accepting...'
                                        : _isExpired
                                            ? 'Expired'
                                            : 'Accept Offer',
                                    style: GoogleFonts.inter(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),''');

  file.writeAsStringSync(content);
}
