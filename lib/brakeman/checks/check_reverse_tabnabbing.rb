require 'brakeman/checks/base_check'

class Brakeman::CheckReverseTabnabbing < Brakeman::BaseCheck
  Brakeman::Checks.add self

  @description = "Checks for reverse tabnabbing cases on 'link_to' calls"

  def run_check
    calls = tracker.find_call :methods => :link_to
    calls.each do |call|
      process_result call
    end
  end

  def process_result result
    return unless original? result and result[:call].last_arg

    html_opts = result[:call].last_arg
    return unless hash? html_opts

    target = hash_access html_opts, :target
    return unless target && string?(target) && target.value == "_blank"

    target_url = result[:block] ? result[:call].first_arg : result[:call].second_arg

    # `url_for` and `_path` calls lead to urls on to the same origin.
    # That means that an adversary would need to run javascript on
    # the victim application's domain. If that is the case, the adversary
    # already has the ability to redirect the victim user anywhere.
    # Also statically provided URLs (interpolated or otherwise) are also
    # ignored as they produce many false positives.
    return if !call?(target_url) || target_url.method.match(/^url_for$|_path$/)

    rel = hash_access html_opts, :rel
    confidence = :medium

    if rel && string?(rel) then
      rel = rel.value
      return if rel.include?("noopener") && rel.include?("noreferrer")

      if rel.include?("noopener") ^ rel.include?("noreferrer") then
        confidence = :weak
      end
    end

    warn :result => result,
      :warning_type => "Reverse Tabnabbing",
      :warning_code => :reverse_tabnabbing,
      :message => "The newly opened tab can control the parent tab's " +
                  "location, thus redirect it to a phishing page",
      :confidence => confidence
  end
end
