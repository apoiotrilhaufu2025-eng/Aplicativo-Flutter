// lib/widgets/nfc_interaction_dialog.dart
import 'dart:async';
import 'package:aplicativo_trilha/main.dart'; 
import 'package:aplicativo_trilha/models/nfc_read_result.dart'; 
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:nfc_manager/nfc_manager.dart';

// Os estados do nosso pop-up
enum NfcStatus { ready, processing, success, error }

class NfcInteractionDialog extends StatefulWidget {
  const NfcInteractionDialog({super.key});

  @override
  State<NfcInteractionDialog> createState() => _NfcInteractionDialogState();
}

class _NfcInteractionDialogState extends State<NfcInteractionDialog> {
  NfcStatus _status = NfcStatus.ready;
  String _message = "Aproxime o celular da Tag NFC...";

  @override
  void initState() {
    super.initState();
    _startNfcSession();
  }

  /// 1. Inicia a sessão NFC 
  Future<void> _startNfcSession() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      setState(() {
        _status = NfcStatus.error;
        _message = "NFC não está disponível ou desativado.";
      });
      return;
    }

    try {
      await NfcManager.instance.startSession(
        onDiscovered: _onNfcDiscovered,
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
      );
    } catch (e) {
      setState(() {
        _status = NfcStatus.error;
        _message = "Erro ao iniciar sessão NFC: $e";
      });
      await _stopSessionAfterDelay(success: false);
    }
  }

  /// 2. Callback de quando a tag é descoberta 
  Future<void> _onNfcDiscovered(NfcTag tag) async {
    if (_status == NfcStatus.processing || _status == NfcStatus.success) return;

    setState(() {
      _status = NfcStatus.processing;
      _message = "Tag lida! Lendo ID Mestre...";
    });

    // 3. Lê os dados da tag (ID Lógico + Logs)
    // Chama o nfcService global (do main.dart)
    final NfcReadResult nfcData = await nfcService.readTagData(tag);
    
    final int? logicalId = nfcData.logicalId;
    
    // 4. Verifica se a tag é válida (tem um ID Lógico)
    if (logicalId == null) {
      setState(() {
        _status = NfcStatus.error;
        _message = "Tag inválida! Não é uma tag da trilha.";
      });
      await _stopSessionAfterDelay(success: false);
      return;
    }
    
    // 5. Se a tag é válida, chama o "maestro"
    setState(() => _message = "Tag $logicalId encontrada! Gravando seu log...");

    // Chama o tagReadService global (do main.dart)
    final bool success = await tagReadService.handleRealNfcRead(
      logicalId.toString(),
      tag, // Passa o objeto NfcTag REAL
    );
    
    if (success) {
      setState(() {
        _status = NfcStatus.success;
        _message = "Sucesso! Evento registrado na Tag $logicalId.";
      });
      await _stopSessionAfterDelay(success: true);
    } else {
      setState(() {
        _status = NfcStatus.error;
        _message = "Erro ao processar. Tente novamente.";
      });
      await _stopSessionAfterDelay(success: false);
    }
  }

  /// 4. Para a sessão e fecha o pop-up
  Future<void> _stopSessionAfterDelay({required bool success}) async {
    await Future.delayed(const Duration(milliseconds: 2500));
    
    try {
      await NfcManager.instance.stopSession();
    } catch (e) {
      print("[NfcInteractionDialog] Erro ao parar sessão: $e");
    }
    
    if (mounted) {
      Navigator.pop(context, success); // Devolve 'true' se deu certo
    }
  }

  @override
  void dispose() {
    try {
      NfcManager.instance.stopSession();
    } catch (e) {
      print("[NfcInteractionDialog] Erro ao parar sessão no dispose: $e");
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        height: 300,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mostra a animação correta para cada estado
            if (_status == NfcStatus.ready)
              Lottie.asset(
                'assets/animations/nfc_scan_animation.json', 
                height: 150,
              ),
            
            if (_status == NfcStatus.processing)
              const CircularProgressIndicator(strokeWidth: 5),

            if (_status == NfcStatus.success)
              Lottie.asset(
                'assets/animations/success_animation.json', 
                height: 150,
              ),
            
            if (_status == NfcStatus.error)
              const Icon(Icons.error_outline, color: Colors.red, size: 100),

            const SizedBox(height: 24),
            Text(
              _message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}