<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Laravel\Passport\Client;
use Laravel\Passport\ClientRepository;

/**
 * OAuth 客户端（第三方应用）管理接口。
 *
 * Laravel Passport 13 调整了客户端相关的数据结构（redirect_uris 数组、
 * secret 只保存哈希、id 变为 UUID 等），并且默认不再注册旧的 JSON API 路由。
 * 为了兼容 Blessing Skin 前端（React）所期望的 `id / name / secret / redirect`
 * 结构，这里基于 Passport 的 ClientRepository 重新实现了一组兼容接口。
 */
class OAuthClientController extends Controller
{
    public function __construct(protected ClientRepository $clients)
    {
    }

    public function index(Request $request)
    {
        return $this->clients
            ->forUser($request->user())
            ->map(fn (Client $client) => $this->transform($client))
            ->values();
    }

    public function store(Request $request)
    {
        $this->validateClient($request);

        $client = $this->clients->createAuthorizationCodeGrantClient(
            $request->input('name'),
            $this->parseRedirectUris($request->input('redirect')),
            true,
            $request->user()
        );

        return response()->json($this->transform($client), 201);
    }

    public function update(Request $request, string $client)
    {
        $model = $this->clients->findForUser($client, $request->user());
        if (is_null($model)) {
            return response()->json(['message' => 'Not found.'], 404);
        }

        $this->validateClient($request);

        $this->clients->update(
            $model,
            $request->input('name'),
            $this->parseRedirectUris($request->input('redirect'))
        );

        return response()->json($this->transform($model->refresh()));
    }

    public function destroy(Request $request, string $client)
    {
        $model = $this->clients->findForUser($client, $request->user());
        if (is_null($model)) {
            return response()->json(['message' => 'Not found.'], 404);
        }

        $this->clients->delete($model);

        return response()->json(null, 204);
    }

    protected function validateClient(Request $request): void
    {
        $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'redirect' => ['required', 'string', 'max:2000'],
        ]);
    }

    /**
     * 兼容旧版：redirect 为逗号分隔的回调地址。
     *
     * @return array<int, string>
     */
    protected function parseRedirectUris(?string $redirect): array
    {
        return array_values(array_filter(array_map('trim', explode(',', (string) $redirect))));
    }

    protected function transform(Client $client): array
    {
        return [
            'id' => $client->id,
            'name' => $client->name,
            'secret' => $client->plain_secret ?? '',
            'redirect' => implode(',', (array) $client->redirect_uris),
            'personal_access_client' => (bool) $client->personal_access_client,
            'password_client' => (bool) $client->password_client,
            'revoked' => (bool) $client->revoked,
        ];
    }
}
