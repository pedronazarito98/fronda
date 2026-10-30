import Foundation
import HarnessDomain
import Security

public enum UpdateVerifier {
    public static func verify(candidate: URL, installed: URL) async throws -> String {
        let current = try identity(installed)
        let update = try identity(candidate)
        guard !current.team.isEmpty, current.team == update.team, current.identifier == update.identifier else {
            throw HarnessError(
                "Atualização bloqueada: o pacote deve pertencer ao mesmo Developer ID do app instalado. Builds ad hoc não aceitam atualização distribuída."
            )
        }
        guard let currentBundle = Bundle(url: installed), let updateBundle = Bundle(url: candidate),
            let old = currentBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let new = updateBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            new.compare(old, options: .numeric) == .orderedDescending
        else { throw HarnessError("O pacote precisa ter uma versão mais recente.") }
        let check = try await ProcessRunner.run(
            "/usr/bin/codesign", ["--verify", "--deep", "--strict", candidate.path], cwd: NSTemporaryDirectory())
        guard check.exitCode == 0 else { throw HarnessError("Assinatura do app ou de um helper inválida.") }
        let gatekeeper = try await ProcessRunner.run(
            "/usr/sbin/spctl", ["--assess", "--type", "execute", candidate.path], cwd: NSTemporaryDirectory(),
            timeout: 60)
        guard gatekeeper.exitCode == 0 else {
            throw HarnessError("O Gatekeeper não confirmou a distribuição notarizada. O app atual permanece no lugar.")
        }
        return
            "Fronda \(new): assinatura, identidade e avaliação do Gatekeeper confirmadas. Encerre as runs e substitua o app pelo pacote selecionado; os dados permanecem em Application Support."
    }
    private static func identity(_ url: URL) throws -> (team: String, identifier: String) {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
            SecStaticCodeCheckValidity(code, [], nil) == errSecSuccess
        else { throw HarnessError("Pacote sem assinatura válida.") }
        var information: CFDictionary?
        guard
            SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
                == errSecSuccess, let values = information as? [String: Any]
        else { throw HarnessError("Não foi possível verificar a identidade do pacote.") }
        return (
            values[kSecCodeInfoTeamIdentifier as String] as? String ?? "",
            values[kSecCodeInfoIdentifier as String] as? String ?? ""
        )
    }
}
