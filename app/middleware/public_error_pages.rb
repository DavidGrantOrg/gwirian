# Rails' error pages, with APP_NAME in place of Gwirian when the site is renamed.
# It overrides PublicExceptions' private render_html, so a Rails upgrade that changes that method needs a look here.
class PublicErrorPages < ActionDispatch::PublicExceptions
  private

  def render_html(status)
    return super unless Gwirian.renamed? && File.exist?("#{public_path}/#{status}.html")

    render_format(status, "text/html", Gwirian.public_page(status.to_s))
  end
end
